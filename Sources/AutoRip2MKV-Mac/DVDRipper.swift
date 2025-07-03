import Foundation
import AVFoundation

/// Native DVD ripper that handles decryption and conversion to MKV
class DVDRipper {
    
    // Progress and status tracking
    weak var delegate: DVDRipperDelegate?
    
    private var parser: DVDStructureParser?
    private var decryptor: DVDDecryptor?
    private var isRipping = false
    private var shouldCancel = false
    
    // Ripping configuration
    struct RippingConfiguration {
        let outputDirectory: String
        let selectedTitles: [Int] // Title numbers to rip, empty = all
        let videoCodec: VideoCodec
        let audioCodec: AudioCodec
        let quality: RippingQuality
        let includeSubtitles: Bool
        let includeChapters: Bool
        
        enum VideoCodec {
            case h264, h265, av1
        }
        
        enum AudioCodec {
            case aac, ac3, dts, flac
        }
        
        enum RippingQuality {
            case low, medium, high, lossless
            
            var crf: Int {
                switch self {
                case .low: return 28
                case .medium: return 23
                case .high: return 18
                case .lossless: return 0
                }
            }
        }
    }
    
    init() {
        
    }
    
    // MARK: - Public Interface
    
    /// Start the DVD ripping process
    func startRipping(dvdPath: String, configuration: RippingConfiguration) {
        guard !isRipping else {
            delegate?.ripperDidFail(with: RipperError.alreadyRipping)
            return
        }
        
        isRipping = true
        shouldCancel = false
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try self.performRipping(dvdPath: dvdPath, configuration: configuration)
            } catch {
                DispatchQueue.main.async {
                    self.delegate?.ripperDidFail(with: error)
                    self.isRipping = false
                }
            }
        }
    }
    
    /// Cancel the current ripping operation
    func cancelRipping() {
        shouldCancel = true
    }
    
    /// Check if currently ripping
    var isCurrentlyRipping: Bool {
        return isRipping
    }
    
    // MARK: - Private Implementation
    
    private func performRipping(dvdPath: String, configuration: RippingConfiguration) throws {
        delegate?.ripperDidStart()
        
        // Step 1: Parse DVD structure
        delegate?.ripperDidUpdateStatus("Analyzing DVD structure...")
        parser = DVDStructureParser(dvdPath: dvdPath)
        let titles = try parser!.parseDVDStructure()
        
        guard !titles.isEmpty else {
            throw RipperError.noTitlesFound
        }
        
        // Step 2: Initialize decryptor
        delegate?.ripperDidUpdateStatus("Initializing DVD decryption...")
        let devicePath = findDVDDevice(dvdPath: dvdPath)
        decryptor = DVDDecryptor(devicePath: devicePath)
        try decryptor!.initializeDevice()
        
        // Step 3: Determine which titles to rip
        let titlesToRip: [DVDTitle]
        if configuration.selectedTitles.isEmpty {
            titlesToRip = titles
        } else {
            titlesToRip = titles.filter { configuration.selectedTitles.contains($0.number) }
        }
        
        delegate?.ripperDidUpdateProgress(0.0, currentTitle: nil, totalTitles: titlesToRip.count)
        
        // Step 4: Rip each title
        for (index, title) in titlesToRip.enumerated() {
            if shouldCancel {
                throw RipperError.cancelled
            }
            
            delegate?.ripperDidUpdateStatus("Ripping title \(title.number) (\(title.formattedDuration))...")
            try ripTitle(title, configuration: configuration, titleIndex: index, totalTitles: titlesToRip.count)
        }
        
        // Step 5: Complete
        DispatchQueue.main.async {
            self.delegate?.ripperDidComplete()
            self.isRipping = false
        }
    }
    
    private func ripTitle(_ title: DVDTitle, configuration: RippingConfiguration, titleIndex: Int, totalTitles: Int) throws {
        // Get title key for decryption
        let titleKey = try decryptor!.getTitleKey(titleNumber: title.number, startSector: title.startSector)
        
        // Create output filename
        let outputFileName = "Title_\(String(format: "%02d", title.number))_\(title.formattedDuration.replacingOccurrences(of: ":", with: "-")).mkv"
        let outputPath = configuration.outputDirectory.appending("/\(outputFileName)")
        
        // Extract and decrypt video data
        let tempVideoFile = try extractAndDecryptTitle(title, titleKey: titleKey)
        
        // Convert to MKV
        try convertToMKV(
            inputFile: tempVideoFile,
            outputFile: outputPath,
            title: title,
            configuration: configuration,
            titleIndex: titleIndex,
            totalTitles: totalTitles
        )
        
        // Cleanup temp file
        try? FileManager.default.removeItem(atPath: tempVideoFile)
    }
    
    private func extractAndDecryptTitle(_ title: DVDTitle, titleKey: DVDDecryptor.CSSKey) throws -> String {
        let tempDirectory = NSTemporaryDirectory()
        let tempFileName = "temp_title_\(title.number).vob"
        let tempFilePath = tempDirectory.appending(tempFileName)
        
        guard let outputHandle = FileHandle(forWritingAtPath: tempFilePath) ??
              {
                  FileManager.default.createFile(atPath: tempFilePath, contents: nil)
                  return FileHandle(forWritingAtPath: tempFilePath)
              }() else {
            throw RipperError.failedToCreateTempFile
        }
        
        defer { outputHandle.closeFile() }
        
        // Process each VOB file for this title
        for vobFile in title.vobFiles {
            try processVOBFile(vobFile, title: title, titleKey: titleKey, outputHandle: outputHandle)
        }
        
        return tempFilePath
    }
    
    private func processVOBFile(_ vobFilePath: String, title: DVDTitle, titleKey: DVDDecryptor.CSSKey, outputHandle: FileHandle) throws {
        guard let inputHandle = FileHandle(forReadingAtPath: vobFilePath) else {
            throw RipperError.failedToReadVOB
        }
        
        defer { inputHandle.closeFile() }
        
        let fileSize = inputHandle.seekToEndOfFile()
        inputHandle.seek(toFileOffset: 0)
        
        let sectorSize = 2048
        var currentSector: UInt32 = 0
        var processedBytes: UInt64 = 0
        
        while processedBytes < fileSize {
            if shouldCancel {
                throw RipperError.cancelled
            }
            
            let sectorData = inputHandle.readData(ofLength: sectorSize)
            if sectorData.isEmpty { break }
            
            // Decrypt sector if needed
            let decryptedData = try decryptor!.decryptSector(
                data: sectorData,
                sector: currentSector,
                titleNumber: title.number
            )
            
            outputHandle.write(decryptedData)
            
            currentSector += 1
            processedBytes += UInt64(sectorData.count)
            
            // Update progress occasionally
            if currentSector % 100 == 0 {
                let progress = Double(processedBytes) / Double(fileSize)
                DispatchQueue.main.async {
                    self.delegate?.ripperDidUpdateProgress(progress * 0.5, currentTitle: title, totalTitles: 1) // 50% for extraction
                }
            }
        }
    }
    
    private func convertToMKV(inputFile: String, outputFile: String, title: DVDTitle, 
                             configuration: RippingConfiguration, titleIndex: Int, totalTitles: Int) throws {
        
        // Build FFmpeg command
        var ffmpegArgs = [
            "-i", inputFile,
            "-c:v", getVideoCodecString(configuration.videoCodec),
            "-crf", String(configuration.quality.crf),
            "-c:a", getAudioCodecString(configuration.audioCodec),
            "-map", "0"
        ]
        
        // Add subtitle mapping if requested
        if configuration.includeSubtitles {
            ffmpegArgs.append(contentsOf: ["-c:s", "copy"])
        }
        
        // Add chapter information if requested
        if configuration.includeChapters && !title.chapters.isEmpty {
            let chaptersFile = try createChaptersFile(for: title)
            ffmpegArgs.append(contentsOf: ["-f", "ffmetadata", "-i", chaptersFile])
            defer { try? FileManager.default.removeItem(atPath: chaptersFile) }
        }
        
        // Add metadata
        ffmpegArgs.append(contentsOf: [
            "-metadata", "title=Title \(title.number)",
            "-metadata", "duration=\(title.formattedDuration)"
        ])
        
        ffmpegArgs.append(outputFile)
        
        // Execute FFmpeg
        try executeFFmpeg(args: ffmpegArgs, titleIndex: titleIndex, totalTitles: totalTitles)
    }
    
    private func createChaptersFile(for title: DVDTitle) throws -> String {
        let tempDirectory = NSTemporaryDirectory()
        let chaptersFileName = "chapters_\(title.number).txt"
        let chaptersFilePath = tempDirectory.appending(chaptersFileName)
        
        var chaptersContent = ";FFMETADATA1\n"
        
        for (index, chapter) in title.chapters.enumerated() {
            let startTime = index == 0 ? 0 : Int(title.chapters[index-1].duration * 1000)
            let endTime = Int(chapter.duration * 1000)
            
            chaptersContent += """
            [CHAPTER]
            TIMEBASE=1/1000
            START=\(startTime)
            END=\(endTime)
            title=Chapter \(chapter.number)
            
            """
        }
        
        try chaptersContent.write(toFile: chaptersFilePath, atomically: true, encoding: .utf8)
        return chaptersFilePath
    }
    
    private func executeFFmpeg(args: [String], titleIndex: Int, totalTitles: Int) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/local/bin/ffmpeg")
        process.arguments = args
        
        // Set up progress monitoring
        let pipe = Pipe()
        process.standardError = pipe
        
        let progressQueue = DispatchQueue(label: "ffmpeg.progress")
        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if let output = String(data: data, encoding: .utf8) {
                self.parseFFmpegProgress(output, titleIndex: titleIndex, totalTitles: totalTitles)
            }
        }
        
        try process.run()
        process.waitUntilExit()
        
        pipe.fileHandleForReading.readabilityHandler = nil
        
        guard process.terminationStatus == 0 else {
            throw RipperError.ffmpegFailed
        }
    }
    
    private func parseFFmpegProgress(_ output: String, titleIndex: Int, totalTitles: Int) {
        // Parse FFmpeg progress output
        let lines = output.components(separatedBy: .newlines)
        
        for line in lines {
            if line.contains("time=") {
                // Extract time progress
                let components = line.components(separatedBy: " ")
                for component in components {
                    if component.hasPrefix("time=") {
                        let timeString = String(component.dropFirst(5))
                        // Convert time to progress percentage
                        // This is a simplified version - real implementation would be more robust
                        let baseProgress = Double(titleIndex) / Double(totalTitles)
                        let titleProgress = 0.5 + 0.5 * 0.5 // Simplified progress calculation
                        
                        DispatchQueue.main.async {
                            self.delegate?.ripperDidUpdateProgress(baseProgress + titleProgress / Double(totalTitles), currentTitle: nil, totalTitles: totalTitles)
                        }
                        break
                    }
                }
            }
        }
    }
    
    // MARK: - Utility Functions
    
    private func findDVDDevice(dvdPath: String) -> String {
        // Find the actual device path for the DVD
        // This is a simplified implementation
        return dvdPath
    }
    
    private func getVideoCodecString(_ codec: RippingConfiguration.VideoCodec) -> String {
        switch codec {
        case .h264: return "libx264"
        case .h265: return "libx265"
        case .av1: return "libaom-av1"
        }
    }
    
    private func getAudioCodecString(_ codec: RippingConfiguration.AudioCodec) -> String {
        switch codec {
        case .aac: return "aac"
        case .ac3: return "ac3"
        case .dts: return "dca"
        case .flac: return "flac"
        }
    }
}

// MARK: - Delegate Protocol

protocol DVDRipperDelegate: AnyObject {
    func ripperDidStart()
    func ripperDidUpdateStatus(_ status: String)
    func ripperDidUpdateProgress(_ progress: Double, currentTitle: DVDTitle?, totalTitles: Int)
    func ripperDidComplete()
    func ripperDidFail(with error: Error)
}

// MARK: - Error Types

enum RipperError: Error {
    case alreadyRipping
    case noTitlesFound
    case failedToCreateTempFile
    case failedToReadVOB
    case ffmpegFailed
    case cancelled
    
    var localizedDescription: String {
        switch self {
        case .alreadyRipping:
            return "Already ripping"
        case .noTitlesFound:
            return "No titles found on DVD"
        case .failedToCreateTempFile:
            return "Failed to create temporary file"
        case .failedToReadVOB:
            return "Failed to read VOB file"
        case .ffmpegFailed:
            return "FFmpeg conversion failed"
        case .cancelled:
            return "Operation cancelled"
        }
    }
}
