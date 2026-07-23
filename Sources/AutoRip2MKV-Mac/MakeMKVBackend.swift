import Foundation

/// Drives MakeMKV's headless CLI (`makemkvcon`) to rip Blu-ray discs.
///
/// MakeMKV handles AACS (and BD+) with its own maintained keys — we never ship
/// or manage any decryption keys ourselves. The user supplies their own MakeMKV
/// install; this backend just orchestrates it and reports progress.
///
/// makemkvcon is invoked in robot mode (`-r`), which emits stable, machine-
/// readable lines (PRGV progress, MSG messages) we parse for the UI.
final class MakeMKVBackend {

    enum MakeMKVError: LocalizedError {
        case notInstalled
        case discOpenFailed(String)
        case ripFailed(code: Int32, lastMessage: String)
        case noTitlesRipped
        case cancelled

        var errorDescription: String? {
            switch self {
            case .notInstalled:
                return "MakeMKV is not installed. Install it from makemkv.com to rip Blu-ray discs."
            case .discOpenFailed(let msg):
                return "MakeMKV could not open the disc: \(msg)"
            case .ripFailed(let code, let msg):
                return "MakeMKV failed (exit \(code)): \(msg)"
            case .noTitlesRipped:
                return "MakeMKV produced no output files."
            case .cancelled:
                return "Ripping cancelled."
            }
        }
    }

    /// Standard install locations for the makemkvcon binary.
    private static let candidatePaths = [
        "/Applications/MakeMKV.app/Contents/MacOS/makemkvcon",
        "/usr/local/bin/makemkvcon",
        "/opt/homebrew/bin/makemkvcon"
    ]

    /// Path to makemkvcon, or nil if MakeMKV isn't installed.
    static func executablePath() -> String? {
        candidatePaths.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    static var isInstalled: Bool { executablePath() != nil }

    private var process: Process?
    private let cancelledFlag: () -> Bool

    /// - Parameter isCancelled: polled between progress updates so a user cancel
    ///   terminates makemkvcon promptly.
    init(isCancelled: @escaping () -> Bool) {
        self.cancelledFlag = isCancelled
    }

    /// Rip all titles MakeMKV selects (per its minlength profile) from the disc
    /// at `discPath` into `outputDirectory`. Blocks until makemkvcon exits.
    ///
    /// - Parameters:
    ///   - minLengthSeconds: titles shorter than this are ignored (MakeMKV's own
    ///     main-feature filtering; keeps bonus clutter out).
    ///   - onStatus / onProgress: UI callbacks (already marshalled by the caller).
    /// - Returns: the .mkv files MakeMKV wrote, newest first.
    @discardableResult
    func rip(discPath: String,
             outputDirectory: String,
             minLengthSeconds: Int,
             onStatus: @escaping (String) -> Void,
             onProgress: @escaping (Double) -> Void) throws -> [String] {

        guard let exe = Self.executablePath() else { throw MakeMKVError.notInstalled }

        try FileManager.default.createDirectory(
            atPath: outputDirectory, withIntermediateDirectories: true)

        // Snapshot existing .mkv files so we can report only the new ones.
        let preexisting = Set((try? FileManager.default.contentsOfDirectory(atPath: outputDirectory))?
            .filter { $0.hasSuffix(".mkv") } ?? [])

        let discSpec = makemkvDiscSpec(for: discPath)

        let task = Process()
        task.executableURL = URL(fileURLWithPath: exe)
        task.arguments = [
            "-r",                                   // robot (machine-readable) mode
            "--progress=-same",                     // progress on the same stream
            "--minlength=\(minLengthSeconds)",
            "mkv", discSpec, "all", outputDirectory
        ]
        let outPipe = Pipe()
        task.standardOutput = outPipe
        task.standardError = Pipe()
        self.process = task

        var lastMessage = ""
        var cancelObserver: DispatchWorkItem?

        try task.run()

        // Poll for cancellation while makemkvcon runs.
        let cancelPoll = DispatchWorkItem { [weak self, weak task] in
            while task?.isRunning == true {
                if self?.cancelledFlag() == true {
                    task?.terminate()
                    break
                }
                Thread.sleep(forTimeInterval: 0.5)
            }
        }
        cancelObserver = cancelPoll
        DispatchQueue.global(qos: .utility).async(execute: cancelPoll)

        // Parse robot-mode output line by line.
        let handle = outPipe.fileHandleForReading
        var buffer = Data()
        while true {
            let chunk = handle.availableData
            if chunk.isEmpty { break }
            buffer.append(chunk)
            while let nl = buffer.firstIndex(of: 0x0A) {
                let lineData = buffer[buffer.startIndex..<nl]
                buffer.removeSubrange(buffer.startIndex...nl)
                if let line = String(data: lineData, encoding: .utf8) {
                    parseRobotLine(line, onStatus: onStatus, onProgress: onProgress,
                                   lastMessage: &lastMessage)
                }
            }
        }

        task.waitUntilExit()
        cancelObserver?.cancel()
        self.process = nil

        if cancelledFlag() { throw MakeMKVError.cancelled }

        guard task.terminationStatus == 0 else {
            throw MakeMKVError.ripFailed(code: task.terminationStatus, lastMessage: lastMessage)
        }

        let now = Set((try? FileManager.default.contentsOfDirectory(atPath: outputDirectory))?
            .filter { $0.hasSuffix(".mkv") } ?? [])
        func fileSize(_ path: String) -> Int64 {
            (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? Int64) ?? 0 ?? 0
        }
        let newFiles = now.subtracting(preexisting)
            .map { outputDirectory.appending("/\($0)") }
            .sorted { fileSize($0) > fileSize($1) }

        guard !newFiles.isEmpty else { throw MakeMKVError.noTitlesRipped }
        return newFiles
    }

    func terminate() {
        process?.terminate()
    }

    // MARK: - Robot-mode parsing

    /// makemkvcon -r emits CSV-ish lines: PRGV (progress values), MSG (messages),
    /// PRGC/PRGT (current/total operation names). We surface MSG text and PRGV %.
    private func parseRobotLine(_ line: String,
                                onStatus: (String) -> Void,
                                onProgress: (Double) -> Void,
                                lastMessage: inout String) {
        if line.hasPrefix("PRGV:") {
            // PRGV:current,total,max
            let nums = line.dropFirst(5).split(separator: ",").compactMap { Double($0) }
            if nums.count == 3, nums[2] > 0 {
                onProgress(min(max(nums[1] / nums[2], 0), 1))
            }
        } else if line.hasPrefix("MSG:") {
            // MSG:code,flags,count,message,format,params...
            let fields = parseRobotCSV(String(line.dropFirst(4)))
            if fields.count >= 4 {
                let message = fields[3]
                lastMessage = message
                onStatus(message)
            }
        } else if line.hasPrefix("PRGC:") || line.hasPrefix("PRGT:") {
            let fields = parseRobotCSV(String(line.drop(while: { $0 != ":" }).dropFirst()))
            if let name = fields.last, !name.isEmpty {
                onStatus(name)
            }
        }
    }

    /// Split a MakeMKV robot-mode CSV line, honoring "quoted" fields.
    private func parseRobotCSV(_ s: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        for ch in s {
            switch ch {
            case "\"": inQuotes.toggle()
            case "," where !inQuotes: fields.append(current); current = ""
            default: current.append(ch)
            }
        }
        fields.append(current)
        return fields
    }

    /// MakeMKV addresses discs as `disc:N` or `dev:/path`. A mounted BDMV path
    /// or /dev node maps to a dev spec; a bare index would be `disc:0`.
    private func makemkvDiscSpec(for discPath: String) -> String {
        if discPath.hasPrefix("/dev/") {
            return "dev:\(discPath)"
        }
        // Mounted volume — hand MakeMKV the mount path; it resolves the device.
        return "dev:\(discPath)"
    }
}
