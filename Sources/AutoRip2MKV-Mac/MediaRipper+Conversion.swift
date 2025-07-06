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
            "-c:v", videoCodecArgument(for: configuration.videoCodec),
            "-crf", "\(configuration.quality.crf)",
            "-c:a", audioCodecArgument(for: configuration.audioCodec)
        ]

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

    private func getFFmpegPath() throws -> String {
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
            return installedFFmpeg
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

    private func videoCodecArgument(for codec: RippingConfiguration.VideoCodec) -> String {
        switch codec {
        case .h264:
            return "libx264"
        case .h265:
            return "libx265"
        case .av1:
            return "libaom-av1"
        }
    }

    private func audioCodecArgument(for codec: RippingConfiguration.AudioCodec) -> String {
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
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffmpegPath)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardError = pipe

        // Start the process
        try process.run()

        // Monitor progress
        let progressQueue = DispatchQueue(label: "ffmpeg.progress")
        progressQueue.async {
            self.monitorFFmpegProgress(pipe: pipe, mediaItem: mediaItem, itemIndex: itemIndex, totalItems: totalItems)
        }

        // Wait for completion
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw MediaRipperError.conversionFailed
        }
    }

    private func monitorFFmpegProgress(pipe: Pipe, mediaItem: MediaItem, itemIndex: Int, totalItems: Int) {
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

        let conversionProgress = min(currentTime / totalDuration, 1.0)

        // Conversion is the second half of the process (50-100%)
        let overallProgress = 0.5 + (conversionProgress * 0.5)

        DispatchQueue.main.async {
            self.delegate?.ripperDidUpdateProgress(overallProgress, currentItem: mediaItem, totalItems: totalItems)
        }
    }

    func mediaTypeString(_ type: MediaType) -> String {
        switch type {
        case .dvd:
            return "DVD"
        case .ultraHDDVD:
            return "Ultra HD DVD"
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
