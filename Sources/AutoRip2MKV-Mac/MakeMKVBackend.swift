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
        case registrationRequired(String)
        case insufficientSpace(neededBytes: Int64, freeBytes: Int64)

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
            case .registrationRequired(let msg):
                return "MakeMKV needs a license key to continue (\(msg)). "
                    + "While MakeMKV is in beta, a free key is published at "
                    + "makemkv.com — or a purchased key can be entered once and kept forever."
            case .insufficientSpace(let needed, let free):
                let fmt = ByteCountFormatter()
                fmt.countStyle = .file
                return "Not enough disk space to rip this disc. "
                    + "Need about \(fmt.string(fromByteCount: needed)), "
                    + "but only \(fmt.string(fromByteCount: free)) is free at the output location. "
                    + "Free up space or choose a different output drive."
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

    /// The MakeMKV.app bundle path, if installed, derived from the makemkvcon path.
    static func appBundlePath() -> String? {
        guard let exe = executablePath() else { return nil }
        // .../MakeMKV.app/Contents/MacOS/makemkvcon -> .../MakeMKV.app
        if let range = exe.range(of: "/Contents/MacOS/") {
            return String(exe[..<range.lowerBound])
        }
        return nil
    }

    /// True if makemkvcon carries the com.apple.quarantine attribute — meaning
    /// Gatekeeper will block it (MakeMKV isn't notarized). Rips fail opaquely
    /// (exit 9, no output) until it's cleared.
    static func isQuarantined() -> Bool {
        guard let exe = executablePath() else { return false }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
        task.arguments = ["-p", "com.apple.quarantine", exe]
        task.standardOutput = Pipe()
        task.standardError = Pipe()
        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0  // attribute present
        } catch {
            return false
        }
    }

    /// Recursively clear the quarantine attribute from the MakeMKV bundle. This
    /// is a non-privileged operation (no password), so it's safe to run for the
    /// user. Returns true on success.
    @discardableResult
    static func clearQuarantine() -> Bool {
        guard let app = appBundlePath() else { return false }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
        task.arguments = ["-dr", "com.apple.quarantine", app]
        task.standardOutput = Pipe()
        task.standardError = Pipe()
        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            return false
        }
    }

    // MARK: - Registration / licensing

    /// Where the MakeMKV purchase page lives.
    static let purchaseURL = URL(string: "https://www.makemkv.com/buy/")!

    /// Forum thread where MakeMKV's developer publishes the free beta key
    /// (rotated every ~2 months while the program is in beta).
    static let betaKeyForumURL = URL(string: "https://forum.makemkv.com/forum/viewtopic.php?f=5&t=1053")!

    /// MakeMKV stores its registration key in ~/.MakeMKV/settings.conf as
    /// app_Key = "T-...". Presence of a key doesn't guarantee validity (beta
    /// keys expire), so this is a hint for messaging, not a gate.
    static func hasLicenseKey(
        settingsPath: String = NSString(string: "~/.MakeMKV/settings.conf").expandingTildeInPath
    ) -> Bool {
        guard let contents = try? String(contentsOfFile: settingsPath, encoding: .utf8) else {
            return false
        }
        for line in contents.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("app_Key"), trimmed.contains("\"T-") {
                return true
            }
        }
        return false
    }

    /// Register a license key via `makemkvcon reg` (MakeMKV's own CLI path for
    /// this — we never edit its settings file ourselves). Returns true when
    /// makemkvcon accepts and saves the key.
    static func register(key: String) -> Bool {
        guard let exe = executablePath() else { return false }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: exe)
        task.arguments = ["reg", key]
        task.standardOutput = Pipe()
        task.standardError = Pipe()
        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            return false
        }
    }

    /// True for the "opened in OS access mode" message — the weak fallback that
    /// fails UHD reads. Its counterpart "direct disc access mode" is the mode a
    /// successful UHD rip needs.
    static func isOSAccessModeMessage(_ message: String) -> Bool {
        message.lowercased().contains("opened in os access mode")
    }

    /// True for the "using direct disc access mode" message — the healthy mode.
    static func isDirectAccessModeMessage(_ message: String) -> Bool {
        message.lowercased().contains("direct disc access")
    }

    /// Messages makemkvcon emits when it refuses to work without a (valid,
    /// current) license key: expired 30-day trial, expired beta build, or an
    /// expired/invalid beta key.
    static func isRegistrationFailureMessage(_ message: String) -> Bool {
        let lower = message.lowercased()
        return lower.contains("evaluation period has expired")
            || lower.contains("registration key")
            || lower.contains("version is too old")
            || lower.contains("shareware")
    }

    /// Extract the current free beta key from the forum thread's HTML. The key
    /// is posted inline as T-<~66 chars of [A-Za-z0-9@_]>.
    static func extractBetaKey(fromForumHTML html: String) -> String? {
        guard let range = html.range(of: "T-[A-Za-z0-9@_]{50,80}", options: .regularExpression) else {
            return nil
        }
        return String(html[range])
    }

    /// Fetch the current free beta key from the MakeMKV forum. Calls back on an
    /// arbitrary queue with the key, or nil if the page couldn't be fetched or
    /// no key was found (thread layout changed, network down, etc.).
    static func fetchBetaKey(completion: @escaping (String?) -> Void) {
        let task = URLSession.shared.dataTask(with: betaKeyForumURL) { data, _, _ in
            guard let data = data, let html = String(data: data, encoding: .utf8) else {
                completion(nil)
                return
            }
            completion(extractBetaKey(fromForumHTML: html))
        }
        task.resume()
    }

    // MARK: - Disk-space preflight

    /// Fraction of the estimated rip size to require free as headroom, on top of
    /// the estimate itself (temp files, muxing overhead, filesystem slack).
    static let spaceSafetyMargin: Double = 1.15

    /// Free space (bytes) available to the user at `path`'s volume, or nil if it
    /// can't be determined.
    static func freeSpace(atPath path: String) -> Int64? {
        let url = URL(fileURLWithPath: path)
        if let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
           let important = values.volumeAvailableCapacityForImportantUsage {
            return Int64(important)
        }
        // Fallback for volumes that don't report the "important usage" key.
        if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: path),
           let free = attrs[.systemFreeSize] as? Int64 {
            return free
        }
        return nil
    }

    /// Estimate the bytes a rip of `blurayPath` will write. MakeMKV remuxes
    /// without re-encoding, so output ≈ the size of the titles it keeps. As a
    /// robust proxy we sum the STREAM/*.m2ts files; if MakeMKV's minlength filter
    /// keeps only the main feature the real output is smaller, so this errs on
    /// the safe (larger) side. Returns 0 if the stream directory can't be read.
    static func estimatedRipSize(forDiscAt blurayPath: String) -> Int64 {
        let streamDir = (blurayPath as NSString).appendingPathComponent("BDMV/STREAM")
        guard let entries = try? FileManager.default.contentsOfDirectory(atPath: streamDir) else {
            return 0
        }
        // The largest single title is the floor of what we must fit; the full sum
        // is the ceiling. Require the largest title plus a share of the rest so a
        // multi-title rip isn't underestimated, without demanding the whole disc.
        let sizes = entries
            .filter { $0.lowercased().hasSuffix(".m2ts") }
            .map { name -> Int64 in
                let p = (streamDir as NSString).appendingPathComponent(name)
                let attrs = try? FileManager.default.attributesOfItem(atPath: p)
                return (attrs?[.size] as? Int64) ?? 0
            }
        guard let largest = sizes.max() else { return 0 }
        return largest
    }

    /// Throw `.insufficientSpace` if the output volume can't hold the estimated
    /// rip (plus safety margin). A no-op when either value is unknown (0/nil),
    /// so we never block a rip on a measurement we couldn't take.
    static func preflightDiskSpace(discPath: String, outputDirectory: String) throws {
        let estimate = estimatedRipSize(forDiscAt: discPath)
        guard estimate > 0, let free = freeSpace(atPath: outputDirectory) else { return }
        let needed = Int64(Double(estimate) * spaceSafetyMargin)
        if free < needed {
            throw MakeMKVError.insufficientSpace(neededBytes: needed, freeBytes: free)
        }
    }

    private var process: Process?
    private let cancelledFlag: () -> Bool

    /// Set while parsing rip output if makemkvcon reported a licensing refusal;
    /// lets us convert an opaque failure into .registrationRequired.
    private var registrationProblem: String?

    /// Set while parsing rip output if makemkvcon reported it could only open the
    /// drive in the weak "OS access mode" (not "direct disc access"). On UHD this
    /// causes "Failed to open disc" / empty output, and it's usually transient
    /// drive contention — so it's worth one retry after the drive settles.
    private var openedInOSAccessMode = false

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

        // Enumerating drives (resolveDiscSpec) opens the physical drive in its own
        // makemkvcon process. On UHD the drive needs a moment to release direct
        // access before the rip re-opens it; without a gap the rip can catch the
        // drive still busy and fall back to the weak "OS access mode", which fails
        // ("Failed to open disc" / no output). Enumerate, let the drive settle,
        // then rip.
        let discSpec = try resolveDiscSpec(for: discPath, makemkvcon: exe)
        onStatus("Opening disc (\(discSpec))...")
        Thread.sleep(forTimeInterval: Self.driveSettleSeconds)

        do {
            return try ripOnce(exe: exe, discSpec: discSpec,
                               outputDirectory: outputDirectory,
                               minLengthSeconds: minLengthSeconds,
                               onStatus: onStatus, onProgress: onProgress)
        } catch let error as MakeMKVError {
            // Retry exactly once if the failure looks like transient drive
            // contention (OS-access-mode fallback). Don't retry cancellations,
            // licensing failures, or genuine disc errors.
            guard shouldRetryForAccessMode(error), !cancelledFlag() else { throw error }
            onStatus("Drive was busy — retrying in direct access mode...")
            Thread.sleep(forTimeInterval: Self.driveRetrySettleSeconds)
            return try ripOnce(exe: exe, discSpec: discSpec,
                               outputDirectory: outputDirectory,
                               minLengthSeconds: minLengthSeconds,
                               onStatus: onStatus, onProgress: onProgress)
        }
    }

    /// Seconds to let the drive settle after enumeration releases it, before the
    /// rip re-opens it.
    private static let driveSettleSeconds: TimeInterval = 2

    /// Longer settle before a contention retry, to give macOS auto-mount and the
    /// prior open time to fully release the device.
    private static let driveRetrySettleSeconds: TimeInterval = 4

    /// A rip failure is retryable when the drive only opened in OS access mode
    /// (weak fallback) — the hallmark of transient contention on UHD discs.
    /// Licensing, cancellation, and no-titles-on-a-clean-open are not retried.
    private func shouldRetryForAccessMode(_ error: MakeMKVError) -> Bool {
        guard openedInOSAccessMode else { return false }
        switch error {
        case .ripFailed, .noTitlesRipped, .discOpenFailed:
            return true
        case .registrationRequired, .cancelled, .notInstalled, .insufficientSpace:
            return false
        }
    }

    /// A single rip attempt against an already-resolved disc spec.
    @discardableResult
    private func ripOnce(exe: String,
                         discSpec: String,
                         outputDirectory: String,
                         minLengthSeconds: Int,
                         onStatus: @escaping (String) -> Void,
                         onProgress: @escaping (Double) -> Void) throws -> [String] {

        // Reset per-attempt state so a prior attempt's flags don't leak.
        registrationProblem = nil
        openedInOSAccessMode = false

        // Mark the start time so we can identify files this run produces by
        // modification time. Filename-based diffing fails when a prior failed
        // attempt left a partial .mkv of the same name that this run overwrites.
        let ripStart = Date()

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
            if let problem = registrationProblem {
                throw MakeMKVError.registrationRequired(problem)
            }
            throw MakeMKVError.ripFailed(code: task.terminationStatus, lastMessage: lastMessage)
        }

        // Collect .mkv files written or modified during this run (mod time at or
        // after ripStart), so a rip that overwrites a same-named partial from a
        // prior failed attempt is still detected. Allow a small clock skew.
        let cutoff = ripStart.addingTimeInterval(-2)
        func attr(_ path: String, _ key: FileAttributeKey) -> Any? {
            try? FileManager.default.attributesOfItem(atPath: path)[key]
        }
        func fileSize(_ path: String) -> Int64 { (attr(path, .size) as? Int64) ?? 0 }
        func modDate(_ path: String) -> Date { (attr(path, .modificationDate) as? Date) ?? .distantPast }

        let allMKVs = (try? FileManager.default.contentsOfDirectory(atPath: outputDirectory))?
            .filter { $0.hasSuffix(".mkv") }
            .map { outputDirectory.appending("/\($0)") } ?? []
        let newFiles = allMKVs
            .filter { modDate($0) >= cutoff }
            .sorted { fileSize($0) > fileSize($1) }

        guard !newFiles.isEmpty else {
            // An expired trial/key can end with exit 0 but nothing ripped —
            // surface the licensing cause rather than a generic empty-output error.
            if let problem = registrationProblem {
                throw MakeMKVError.registrationRequired(problem)
            }
            throw MakeMKVError.noTitlesRipped
        }
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
                if Self.isRegistrationFailureMessage(message) {
                    registrationProblem = message
                }
                // Track which access mode the drive opened in. "direct disc
                // access mode" clears the flag (success); "OS access mode" is the
                // weak fallback that fails UHD reads and warrants a retry.
                if Self.isDirectAccessModeMessage(message) {
                    openedInOSAccessMode = false
                } else if Self.isOSAccessModeMessage(message) {
                    openedInOSAccessMode = true
                }
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

    /// Enumerate title durations (seconds) for the disc, by parsing `makemkvcon
    /// info`'s TINFO lines. This is the input to movie-vs-TV classification.
    ///
    /// TINFO line format: `TINFO:title,id,code,"value"`. Duration is id 9, given
    /// as `HH:MM:SS`. Returns one entry per enumerated title (order preserved),
    /// or an empty array if the scan fails.
    ///
    /// NOTE: this opens the drive, so never call it while a rip is active — see
    /// the drive-contention notes on `rip`.
    func scanTitleDurations(for discPath: String) -> [Int] {
        guard let exe = Self.executablePath() else { return [] }
        let discSpec = (try? resolveDiscSpec(for: discPath, makemkvcon: exe)) ?? "disc:0"

        let task = Process()
        task.executableURL = URL(fileURLWithPath: exe)
        task.arguments = ["-r", "--cache=1", "--minlength=0", "info", discSpec]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        guard (try? task.run()) != nil else { return [] }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        let output = String(data: data, encoding: .utf8) ?? ""
        return Self.parseTitleDurations(fromInfoOutput: output)
    }

    /// Parse title durations (seconds) from robot-mode `info` output. Pure, so
    /// it can be unit-tested against captured makemkvcon output.
    static func parseTitleDurations(fromInfoOutput output: String) -> [Int] {
        // title index -> duration seconds, keyed to preserve one entry per title.
        var byTitle: [Int: Int] = [:]
        for rawLine in output.split(separator: "\n") where rawLine.hasPrefix("TINFO:") {
            let fields = parseRobotCSVStatic(String(rawLine.dropFirst("TINFO:".count)))
            // TINFO:title,id,code,"value" — duration is id == 9.
            guard fields.count >= 4,
                  let title = Int(fields[0]),
                  let id = Int(fields[1]), id == 9 else { continue }
            if let seconds = parseHMS(fields[3]) {
                byTitle[title] = seconds
            }
        }
        return byTitle.keys.sorted().compactMap { byTitle[$0] }
    }

    /// Parse an `HH:MM:SS` (or `H:MM:SS`) duration string to seconds.
    static func parseHMS(_ s: String) -> Int? {
        let parts = s.split(separator: ":").map { Int($0) }
        guard parts.allSatisfy({ $0 != nil }) else { return nil }
        let nums = parts.compactMap { $0 }
        switch nums.count {
        case 3: return nums[0] * 3600 + nums[1] * 60 + nums[2]
        case 2: return nums[0] * 60 + nums[1]
        case 1: return nums[0]
        default: return nil
        }
    }

    /// Static twin of `parseRobotCSV` for use from static parsing helpers.
    private static func parseRobotCSVStatic(_ s: String) -> [String] {
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

    /// Resolve the disc identifier MakeMKV expects. MakeMKV addresses optical
    /// drives by its own enumeration index (`disc:N`) or by device node
    /// (`dev:/dev/rdiskN`) — NOT by mount path. We ask makemkvcon to enumerate
    /// drives (`info disc:9999` prints DRV: lines) and match ours by mount
    /// volume name or device node, returning `disc:<index>`.
    ///
    /// DRV line format: DRV:index,visible,enabled,flags,"drive name","disc name","device path"
    private func resolveDiscSpec(for discPath: String, makemkvcon exe: String) throws -> String {
        // If we were handed a raw device node directly, use it.
        if discPath.hasPrefix("/dev/") {
            return "dev:\(discPath)"
        }

        let volumeName = (discPath as NSString).lastPathComponent

        let task = Process()
        task.executableURL = URL(fileURLWithPath: exe)
        task.arguments = ["-r", "--cache=1", "info", "disc:9999"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        try task.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        let output = String(data: data, encoding: .utf8) ?? ""

        for line in output.split(separator: "\n") where line.hasPrefix("DRV:") {
            // index is the first field after "DRV:"
            let fields = parseRobotCSV(String(line.dropFirst(4)))
            guard fields.count >= 7, let index = Int(fields[0]) else { continue }
            let discName = fields[5]
            let devicePath = fields[6]
            // Match by disc/volume name or by resolving the mount to the device.
            if discName == volumeName || devicePath.contains(volumeName) {
                return "disc:\(index)"
            }
        }

        // Fall back to the first enumerated drive that has a disc loaded.
        for line in output.split(separator: "\n") where line.hasPrefix("DRV:") {
            let fields = parseRobotCSV(String(line.dropFirst(4)))
            if fields.count >= 7, let index = Int(fields[0]), !fields[6].isEmpty {
                return "disc:\(index)"
            }
        }

        throw MakeMKVError.discOpenFailed("No MakeMKV drive matched \(volumeName)")
    }
}
