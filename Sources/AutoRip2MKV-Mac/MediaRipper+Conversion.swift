import Foundation
import AVFoundation

// MARK: - Media Conversion Implementation

extension MediaRipper {

    func convertToMKV(
        inputFile: String,
        outputFile: String,
        mediaItem: MediaItem,
        configuration: RippingConfiguration,
        itemIndex: Int,
        totalItems: Int
    ) throws {
        // Build FFmpeg command
        let ffmpegPath = try getFFmpegPath()

        var arguments = ["-i", inputFile]

        // Video encoder (hardware or software) with its rate-control parameters
        arguments.append(contentsOf: videoEncoderArguments(for: configuration, ffmpegPath: ffmpegPath))

        // Add audio codec
        arguments.append(contentsOf: audioEncoderArguments(for: configuration.audioCodec))

        // Add subtitle handling if requested
        if configuration.includeSubtitles {
            arguments.append(contentsOf: ["-c:s", "copy"])
        }

        // Add chapter handling if requested
        if configuration.includeChapters {
            arguments.append(contentsOf: ["-map_chapters", "0"])
        }

        // Output file
        arguments.append(outputFile)

        // Run FFmpeg conversion
        try runFFmpegConversion(
            ffmpegPath: ffmpegPath,
            arguments: arguments,
            mediaItem: mediaItem,
            itemIndex: itemIndex,
            totalItems: totalItems
        )
    }

    private func isValidMachO(atPath path: String) -> Bool {
        guard let fh = FileHandle(forReadingAtPath: path),
              let magic = try? fh.read(upToCount: 4) else { return false }
        fh.closeFile()
        let bytes = [UInt8](magic)
        return (bytes == [0xCF, 0xFA, 0xED, 0xFE]) ||
               (bytes == [0xCE, 0xFA, 0xED, 0xFE]) ||
               (bytes == [0xCA, 0xFE, 0xBA, 0xBE])
    }

    /// True when the Mach-O at `path` can run natively on Apple Silicon (a thin
    /// arm64 binary, or a universal binary with an arm64 slice). An x86_64-only
    /// ffmpeg runs under Rosetta, where VideoToolbox rejects constant-quality
    /// (`-q:v`) encodes and every hardware encode fails at once.
    static func binarySupportsArm64(atPath path: String) -> Bool {
        guard let fh = FileHandle(forReadingAtPath: path),
              let header = try? fh.read(upToCount: 4096) else { return false }
        fh.closeFile()
        let bytes = [UInt8](header)
        guard bytes.count >= 8 else { return false }
        func le32(_ o: Int) -> UInt32 {
            UInt32(bytes[o]) | UInt32(bytes[o + 1]) << 8 | UInt32(bytes[o + 2]) << 16 | UInt32(bytes[o + 3]) << 24
        }
        func be32(_ o: Int) -> UInt32 {
            UInt32(bytes[o]) << 24 | UInt32(bytes[o + 1]) << 16 | UInt32(bytes[o + 2]) << 8 | UInt32(bytes[o + 3])
        }
        let cpuTypeARM64: UInt32 = 0x0100_000C
        if bytes[0..<4] == [0xCF, 0xFA, 0xED, 0xFE] {   // thin 64-bit, little-endian
            return le32(4) == cpuTypeARM64
        }
        if bytes[0..<4] == [0xCA, 0xFE, 0xBA, 0xBE] {   // universal (fat) header, big-endian
            let archCount = Int(be32(4))
            for i in 0..<archCount {
                let offset = 8 + i * 20                     // struct fat_arch is 20 bytes
                guard offset + 4 <= bytes.count else { break }
                if be32(offset) == cpuTypeARM64 { return true }
            }
        }
        return false
    }

    /// Whether `path` runs natively on this Mac (always true on Intel Macs).
    static func isNativeBinary(atPath path: String) -> Bool {
        #if arch(arm64)
        return binarySupportsArm64(atPath: path)
        #else
        return true
        #endif
    }

    /// Resolves ffmpeg: bundled → Application Support (downloaded) → Homebrew →
    /// `$PATH`. On Apple Silicon a native build wins over an earlier Intel-only one.
    func getFFmpegPath() throws -> String {
        var candidates: [String] = []
        let fm = FileManager.default

        // 1. Bundled in the app (Contents/Resources), then the legacy bundle lookup
        let bundledFFmpeg = Bundle.main.bundlePath.appending("/Contents/Resources/ffmpeg")
        if fm.fileExists(atPath: bundledFFmpeg) { candidates.append(bundledFFmpeg) }
        if let bundledPath = Bundle.main.path(forResource: "ffmpeg", ofType: nil) {
            candidates.append(bundledPath)
        }

        // 2. Application Support directory (downloaded/installed)
        let installedFFmpeg = (getApplicationSupportPath() as NSString).appendingPathComponent("ffmpeg")
        if fm.fileExists(atPath: installedFFmpeg) {
            if isValidMachO(atPath: installedFFmpeg) {
                candidates.append(installedFFmpeg)
            } else {
                // Corrupt file (e.g. un-extracted ZIP) — remove it so it can be re-downloaded
                try? fm.removeItem(atPath: installedFFmpeg)
            }
        }

        // 3. Homebrew. Apps launched from Finder get a minimal $PATH that
        // doesn't include these, so `which` alone misses them.
        for path in ["/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg"] where fm.isExecutableFile(atPath: path) {
            candidates.append(path)
        }

        // 4. System PATH
        if let path = whichFFmpeg() { candidates.append(path) }

        guard let first = candidates.first else { throw MediaRipperError.ffmpegNotFound }
        let chosen = candidates.first(where: { Self.isNativeBinary(atPath: $0) }) ?? first
        if !Self.isNativeBinary(atPath: chosen) {
            Logger.shared.log("Using non-native (Rosetta) ffmpeg at \(chosen); hardware encoding is disabled",
                              level: .warning, category: .general)
        }
        return chosen
    }

    private func whichFFmpeg() -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["ffmpeg"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return nil
        }
        // Drain before waiting: a full pipe blocks the child
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0,
              let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !path.isEmpty else { return nil }
        return path
    }

    private func getApplicationSupportPath() -> String {
        let fileManager = FileManager.default
        guard let appSupportURL = fileManager.urls(for: .applicationSupportDirectory,
                                                   in: .userDomainMask).first else {
            return NSTemporaryDirectory()
        }

        let appPath = appSupportURL.appendingPathComponent("AutoRip2MKV-Mac")

        // Create directory if it doesn't exist
        if !fileManager.fileExists(atPath: appPath.path) {
            try? fileManager.createDirectory(at: appPath, withIntermediateDirectories: true)
        }

        return appPath.path
    }

    func videoCodecArgument(for codec: RippingConfiguration.VideoCodec) -> String {
        switch codec {
        case .h264:
            return "libx264"
        case .h265:
            return "libx265"
        case .av1:
            return "libaom-av1"
        case .vp9:
            return "libvpx-vp9"
        }
    }

    /// `-c:v …` plus rate control. Uses Apple VideoToolbox when the rip asks for
    /// hardware acceleration and VT can encode it; otherwise the software encoder
    /// with CRF/preset tuning. Pass the ffmpeg that will run the encode: an
    /// Intel-only build under Rosetta can't do VT constant-quality, so it gets
    /// the software encoder.
    func videoEncoderArguments(for configuration: RippingConfiguration, ffmpegPath: String? = nil) -> [String] {
        let ffmpegCanUseVT = ffmpegPath.map { Self.isNativeBinary(atPath: $0) } ?? true
        if configuration.hardwareAcceleration, ffmpegCanUseVT,
           let hardware = videoToolboxArguments(for: configuration.videoCodec, quality: configuration.quality) {
            return hardware
        }
        return ["-c:v", videoCodecArgument(for: configuration.videoCodec)]
            + codecSpecificArguments(for: configuration.videoCodec, quality: configuration.quality)
    }

    /// VideoToolbox encoder arguments, or nil when VT can't honor the request:
    /// AV1/VP9 have no VT encoder, lossless needs the software path, and VT's
    /// constant-quality mode (`-q:v`, 1–100, higher = better) is Apple Silicon only.
    func videoToolboxArguments(for codec: RippingConfiguration.VideoCodec,
                               quality: RippingConfiguration.RippingQuality) -> [String]? {
        #if arch(arm64)
        let encoder: String
        switch codec {
        case .h264: encoder = "h264_videotoolbox"
        case .h265: encoder = "hevc_videotoolbox"
        case .av1, .vp9: return nil
        }
        let q: Int
        switch quality {
        case .low: q = 45
        case .medium: q = 55
        case .high: q = 65
        case .lossless: return nil
        }
        // -a53cc 0: VT's closed-caption SEI writer emits malformed NAL units, so
        // a DVD with line-21 captions comes out as a corrupt, smeared stream.
        return ["-c:v", encoder, "-q:v", "\(q)", "-a53cc", "0"]
        #else
        return nil
        #endif
    }

    /// `-c:a …`; FFmpeg's DTS encoder is experimental and refuses to run without
    /// `-strict -2`.
    func audioEncoderArguments(for codec: RippingConfiguration.AudioCodec) -> [String] {
        let args = ["-c:a", audioCodecArgument(for: codec)]
        return codec == .dts ? args + ["-strict", "-2"] : args
    }

    /// Generates codec-specific FFmpeg arguments for optimal encoding
    func codecSpecificArguments(for codec: RippingConfiguration.VideoCodec, quality: RippingConfiguration.RippingQuality) -> [String] {
        switch codec {
        case .h264:
            return h264Arguments(quality: quality)
        case .h265:
            return h265Arguments(quality: quality)
        case .av1:
            return av1Arguments(quality: quality)
        case .vp9:
            return vp9Arguments(quality: quality)
        }
    }

    /// H.264 encoding arguments with preset optimization
    private func h264Arguments(quality: RippingConfiguration.RippingQuality) -> [String] {
        var args = ["-crf", "\(quality.crf)"]
        
        // Add preset for speed vs compression tradeoff
        switch quality {
        case .low:
            args.append(contentsOf: ["-preset", "veryfast"])
        case .medium:
            args.append(contentsOf: ["-preset", "medium"])
        case .high:
            args.append(contentsOf: ["-preset", "slow"])
        case .lossless:
            args.append(contentsOf: ["-preset", "medium", "-crf", "0"])
        }
        
        return args
    }

    /// H.265 encoding arguments with preset optimization
    private func h265Arguments(quality: RippingConfiguration.RippingQuality) -> [String] {
        var args = ["-crf", "\(quality.crf)"]
        
        // Add preset for speed vs compression tradeoff
        switch quality {
        case .low:
            args.append(contentsOf: ["-preset", "fast"])
        case .medium:
            args.append(contentsOf: ["-preset", "medium"])
        case .high:
            args.append(contentsOf: ["-preset", "slow"])
        case .lossless:
            args.append(contentsOf: ["-preset", "medium", "-x265-params", "lossless=1"])
        }
        
        return args
    }

    /// AV1 encoding arguments with tile-based encoding and cpu-used optimization
    private func av1Arguments(quality: RippingConfiguration.RippingQuality) -> [String] {
        var args: [String] = []
        
        // AV1 uses different CRF values (0-63 scale, higher = lower quality)
        let av1Crf: Int
        switch quality {
        case .low:
            av1Crf = 38  // Fast, lower quality
        case .medium:
            av1Crf = 32  // Balanced
        case .high:
            av1Crf = 25  // High quality, slower
        case .lossless:
            av1Crf = 0   // Lossless
        }
        
        args.append(contentsOf: ["-crf", "\(av1Crf)"])
        
        // cpu-used: 0-8 (0=slowest/best, 8=fastest/worst)
        let cpuUsed: Int
        switch quality {
        case .low:
            cpuUsed = 8  // Fastest
        case .medium:
            cpuUsed = 4  // Balanced
        case .high:
            cpuUsed = 2  // High quality
        case .lossless:
            cpuUsed = 1  // Best quality
        }
        
        args.append(contentsOf: ["-cpu-used", "\(cpuUsed)"])
        
        // Tile-based encoding for parallel processing
        // Use 2 tile columns and 2 tile rows for better performance
        args.append(contentsOf: [
            "-tile-columns", "2",
            "-tile-rows", "1",
            "-row-mt", "1"  // Enable row-based multithreading
        ])
        
        // Additional AV1-specific optimizations
        if quality == .high || quality == .lossless {
            args.append(contentsOf: [
                "-arnr-maxframes", "7",    // Temporal filtering
                "-arnr-strength", "4"       // Filtering strength
            ])
        }
        
        return args
    }

    /// VP9 encoding arguments with multi-threading and quality optimization
    private func vp9Arguments(quality: RippingConfiguration.RippingQuality) -> [String] {
        var args: [String] = []
        
        // VP9 CRF scale (0-63, higher = lower quality)
        let vp9Crf: Int
        switch quality {
        case .low:
            vp9Crf = 40  // Fast, lower quality
        case .medium:
            vp9Crf = 33  // Balanced
        case .high:
            vp9Crf = 25  // High quality
        case .lossless:
            vp9Crf = 0   // Lossless
        }
        
        args.append(contentsOf: ["-crf", "\(vp9Crf)", "-b:v", "0"])  // VBR mode
        
        // Quality/Speed tradeoff (deadline: good, best, realtime)
        let deadline: String
        let cpuUsed: Int
        switch quality {
        case .low:
            deadline = "realtime"
            cpuUsed = 8  // Fastest
        case .medium:
            deadline = "good"
            cpuUsed = 2  // Balanced
        case .high:
            deadline = "good"
            cpuUsed = 0  // Best quality
        case .lossless:
            deadline = "best"
            cpuUsed = 0  // Best quality with lossless
        }
        
        args.append(contentsOf: ["-deadline", deadline, "-cpu-used", "\(cpuUsed)"])
        
        // Multi-threading support
        let threads = ProcessInfo.processInfo.activeProcessorCount
        args.append(contentsOf: [
            "-threads", "\(threads)",
            "-row-mt", "1",              // Enable row-based multithreading
            "-tile-columns", "2",        // Parallel tile encoding
            "-tile-rows", "1"
        ])
        
        // Quality tuning for high/lossless
        if quality == .high || quality == .lossless {
            args.append(contentsOf: [
                "-auto-alt-ref", "1",     // Enable alternate reference frames
                "-lag-in-frames", "25",   // Lookahead frames for better encoding
                "-arnr-maxframes", "7",   // Temporal filtering
                "-arnr-strength", "4"     // Filtering strength
            ])
        }
        
        if quality == .lossless {
            args.append(contentsOf: ["-lossless", "1"])
        }
        
        return args
    }

    func audioCodecArgument(for codec: RippingConfiguration.AudioCodec) -> String {
        switch codec {
        case .aac:
            return "aac"
        case .ac3:
            return "ac3"
        case .dts:
            return "dca"
        case .flac:
            return "flac"
        }
    }

    private func runFFmpegConversion(
        ffmpegPath: String,
        arguments: [String],
        mediaItem: MediaItem,
        itemIndex: Int,
        totalItems: Int
    ) throws {
        // Log the full FFmpeg command
        let fullCommand = "\(ffmpegPath) \(arguments.joined(separator: " "))"
        delegate?.mediaRipperDidUpdateStatus("Running FFmpeg command:")
        delegate?.mediaRipperDidUpdateStatus(fullCommand)
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffmpegPath)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardError = pipe

        // Start the process
        delegate?.mediaRipperDidUpdateStatus("Starting FFmpeg conversion process...")
        try process.run()

        // Monitor progress
        let progressQueue = DispatchQueue(label: "ffmpeg.progress")
        progressQueue.async {
            self.monitorFFmpegProgress(pipe: pipe, mediaItem: mediaItem, itemIndex: itemIndex, totalItems: totalItems)
        }

        // Wait for completion
        process.waitUntilExit()

        if process.terminationStatus == 0 {
            delegate?.mediaRipperDidUpdateStatus("FFmpeg conversion completed successfully")
        } else {
            delegate?.mediaRipperDidUpdateStatus("FFmpeg conversion failed with exit code: \(process.terminationStatus)")
            throw MediaRipperError.conversionFailed
        }
    }

    /// Drains ffmpeg's stderr, reporting progress, until ffmpeg closes it.
    /// Returns the last non-progress lines so a failed encode can log why.
    @discardableResult
    func monitorFFmpegProgress(pipe: Pipe, mediaItem: MediaItem, itemIndex: Int, totalItems: Int) -> [String] {
        let fileHandle = pipe.fileHandleForReading

        var buffer = Data()
        var tail: [String] = []
        let maxTailLines = 15

        func handle(_ lineData: Data) {
            guard let line = String(data: lineData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespaces), !line.isEmpty else { return }
            if line.contains("time=") {
                parseFFmpegProgress(line: line, mediaItem: mediaItem, itemIndex: itemIndex, totalItems: totalItems)
            } else {
                tail.append(line)
                if tail.count > maxTailLines { tail.removeFirst() }
            }
        }

        while !shouldCancel {
            let chunk = fileHandle.availableData
            if chunk.isEmpty {
                break
            }

            buffer.append(chunk)

            // Process complete lines: progress ends in \r, messages in \n
            while let end = buffer.firstIndex(where: { $0 == 0x0D || $0 == 0x0A }) {
                handle(buffer.subdata(in: buffer.startIndex..<end))
                buffer.removeSubrange(buffer.startIndex...end)
            }

            // Small delay to prevent excessive CPU usage
            usleep(10000) // 10ms
        }
        if !buffer.isEmpty { handle(buffer) }
        return tail
    }

    private func parseFFmpegProgress(line: String, mediaItem: MediaItem, itemIndex: Int, totalItems: Int) {
        // Parse FFmpeg progress output
        // Look for patterns like "time=00:01:23.45"
        if line.contains("time=") {
            let components = line.components(separatedBy: " ")
            for component in components {
                if component.hasPrefix("time=") {
                    let timeString = String(component.dropFirst(5)) // Remove "time="
                    if let currentTime = parseTimeString(timeString) {
                        updateProgressFromTime(
                            currentTime: currentTime,
                            mediaItem: mediaItem,
                            itemIndex: itemIndex,
                            totalItems: totalItems
                        )
                    }
                    break
                }
            }
        }
    }

    private func parseTimeString(_ timeString: String) -> Double? {
        let components = timeString.components(separatedBy: ":")
        guard components.count == 3 else { return nil }

        guard let hours = Double(components[0]),
              let minutes = Double(components[1]),
              let seconds = Double(components[2]) else {
            return nil
        }

        return hours * 3600 + minutes * 60 + seconds
    }

    private func updateProgressFromTime(currentTime: Double, mediaItem: MediaItem, itemIndex: Int, totalItems: Int) {
        let totalDuration: Double

        switch mediaItem {
        case .dvdTitle(let title):
            totalDuration = title.duration
        case .blurayPlaylist(let playlist):
            totalDuration = playlist.duration
        }

        // While the disc is still being read, the feed loop reports sector-based
        // progress; encode-time progress would fight it and move far slower.
        guard !isFeedingDisc else { return }

        let conversionProgress = totalDuration > 0 ? min(currentTime / totalDuration, 1.0) : 0.0

        let itemProgress = (Double(itemIndex) + conversionProgress) / Double(max(totalItems, 1))

        DispatchQueue.main.async {
            self.delegate?.mediaRipperDidUpdateProgress(itemProgress, currentItem: mediaItem, totalItems: totalItems)
        }
    }

    func mediaTypeString(_ type: MediaType) -> String {
        switch type {
        case .dvd:
            return "DVD"
        case .ultraHDDVD:
            return "Ultra HD DVD"
        case .hddvd:
            return "HD DVD"
        case .bluray:
            return "Blu-ray"
        case .bluray4K:
            return "4K Blu-ray"
        case .unknown:
            return "Unknown"
        }
    }
}

// MARK: - Media Item Enum

extension MediaRipper {
    enum MediaItem {
        case dvdTitle(DVDTitle)
        case blurayPlaylist(BluRayPlaylist)
    }
}
