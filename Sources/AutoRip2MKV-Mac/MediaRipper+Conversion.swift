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

        var arguments = [
            "-i", inputFile,
            "-c:v", videoCodecArgument(for: configuration.videoCodec)
        ]

        // Add codec-specific encoding parameters
        arguments.append(contentsOf: codecSpecificArguments(for: configuration.videoCodec, quality: configuration.quality))

        // Add audio codec
        arguments.append(contentsOf: ["-c:a", audioCodecArgument(for: configuration.audioCodec)])

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

    func getFFmpegPath() throws -> String {
        // 1. Check if FFmpeg is bundled in the app bundle (Contents/Resources)
        let bundlePath = Bundle.main.bundlePath
        let bundledFFmpeg = bundlePath.appending("/Contents/Resources/ffmpeg")
        if FileManager.default.fileExists(atPath: bundledFFmpeg) {
            return bundledFFmpeg
        }

        // 2. Check if FFmpeg is bundled using Bundle.main.path (legacy)
        if let bundledPath = Bundle.main.path(forResource: "ffmpeg", ofType: nil) {
            return bundledPath
        }

        // 3. Check Application Support directory (downloaded/installed)
        let appSupportPath = getApplicationSupportPath()
        let installedFFmpeg = (appSupportPath as NSString).appendingPathComponent("ffmpeg")
        if FileManager.default.fileExists(atPath: installedFFmpeg) {
            if isValidMachO(atPath: installedFFmpeg) {
                return installedFFmpeg
            }
            // Corrupt file (e.g. un-extracted ZIP) — remove it so it can be re-downloaded
            try? FileManager.default.removeItem(atPath: installedFFmpeg)
        }

        // 4. Check system PATH as fallback
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["ffmpeg"]

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !path.isEmpty {
                    return path
                }
            }
        } catch {
            throw MediaRipperError.ffmpegNotFound
        }

        throw MediaRipperError.ffmpegNotFound
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

    func monitorFFmpegProgress(pipe: Pipe, mediaItem: MediaItem, itemIndex: Int, totalItems: Int) {
        let fileHandle = pipe.fileHandleForReading

        var buffer = Data()
        let delimiter = Data("\r".utf8)

        while !shouldCancel {
            let chunk = fileHandle.availableData
            if chunk.isEmpty {
                break
            }

            buffer.append(chunk)

            // Process complete lines
            while let delimiterRange = buffer.range(of: delimiter) {
                let lineData = buffer.subdata(in: 0..<delimiterRange.lowerBound)
                buffer.removeSubrange(0..<delimiterRange.upperBound)

                if let line = String(data: lineData, encoding: .utf8) {
                    parseFFmpegProgress(line: line, mediaItem: mediaItem, itemIndex: itemIndex, totalItems: totalItems)
                }
            }

            // Small delay to prevent excessive CPU usage
            usleep(10000) // 10ms
        }
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
