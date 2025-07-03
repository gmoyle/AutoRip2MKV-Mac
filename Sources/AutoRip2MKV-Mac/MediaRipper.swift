import Foundation
import AVFoundation

/// Unified media ripper that handles both DVD and Blu-ray formats with native decryption
class MediaRipper {
    
    // Media type detection
    enum MediaType {
        case dvd
        case bluray
        case unknown
    }
    
    // Progress and status tracking
    weak var delegate: MediaRipperDelegate?
    
    private var dvdParser: DVDStructureParser?
    private var blurayParser: BluRayStructureParser?
    private var dvdDecryptor: DVDDecryptor?
    private var blurayDecryptor: BluRayDecryptor?
    private var isRipping = false
    private var shouldCancel = false
    private var currentMediaType: MediaType = .unknown
    
    // Ripping configuration
    struct RippingConfiguration {
        let outputDirectory: String
        let selectedTitles: [Int] // Title/playlist numbers to rip, empty = all
        let videoCodec: VideoCodec
        let audioCodec: AudioCodec
        let quality: RippingQuality
        let includeSubtitles: Bool
        let includeChapters: Bool
        let mediaType: MediaType? // Optional override for media type detection
        
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
    
    /// Detect media type from directory structure
    func detectMediaType(path: String) -> MediaType {
        let videoTSPath = path.appending("/VIDEO_TS")
        let bdmvPath = path.appending("/BDMV")
        
        if FileManager.default.fileExists(atPath: bdmvPath) {
            return .bluray
        } else if FileManager.default.fileExists(atPath: videoTSPath) {
            return .dvd
        }
        
        return .unknown
    }
    
    /// Start the media ripping process
    func startRipping(mediaPath: String, configuration: RippingConfiguration) {
        guard !isRipping else {
            delegate?.ripperDidFail(with: MediaRipperError.alreadyRipping)
            return
        }
        
        isRipping = true
        shouldCancel = false
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try self.performRipping(mediaPath: mediaPath, configuration: configuration)
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
    
    private func performRipping(mediaPath: String, configuration: RippingConfiguration) throws {
        delegate?.ripperDidStart()
        
        // Step 1: Detect media type
        currentMediaType = configuration.mediaType ?? detectMediaType(path: mediaPath)
        
        delegate?.ripperDidUpdateStatus("Detected \(mediaTypeString(currentMediaType)) media")
        
        switch currentMediaType {
        case .dvd:
            try performDVDRipping(dvdPath: mediaPath, configuration: configuration)
        case .bluray:
            try performBluRayRipping(blurayPath: mediaPath, configuration: configuration)
        case .unknown:
            throw MediaRipperError.unsupportedMediaType
        }
        
        // Complete
        DispatchQueue.main.async {
            self.delegate?.ripperDidComplete()
            self.isRipping = false
        }
    }
    
    // MARK: - DVD Ripping
    
    private func performDVDRipping(dvdPath: String, configuration: RippingConfiguration) throws {
        // Step 1: Parse DVD structure
        delegate?.ripperDidUpdateStatus("Analyzing DVD structure...")
        dvdParser = DVDStructureParser(dvdPath: dvdPath)
        let titles = try dvdParser!.parseDVDStructure()
        
        guard !titles.isEmpty else {
            throw MediaRipperError.noTitlesFound
        }
        
        // Step 2: Initialize DVD decryptor
        delegate?.ripperDidUpdateStatus("Initializing DVD CSS decryption...")
        let devicePath = findDVDDevice(dvdPath: dvdPath)
        dvdDecryptor = DVDDecryptor(devicePath: devicePath)
        try dvdDecryptor!.initializeDevice()
        
        // Step 3: Determine which titles to rip
        let titlesToRip = filterTitlesToRip(titles: titles, selectedTitles: configuration.selectedTitles)
        delegate?.ripperDidUpdateProgress(0.0, currentItem: nil, totalItems: titlesToRip.count)
        
        // Step 4: Rip each title
        for (index, title) in titlesToRip.enumerated() {
            if shouldCancel {
                throw MediaRipperError.cancelled
            }
            
            delegate?.ripperDidUpdateStatus("Ripping DVD title \(title.number) (\(title.formattedDuration))...")
            try ripDVDTitle(title, configuration: configuration, titleIndex: index, totalTitles: titlesToRip.count)
        }
    }
    
    private func ripDVDTitle(_ title: DVDTitle, configuration: RippingConfiguration, titleIndex: Int, totalTitles: Int) throws {
        // Get title key for decryption
        let titleKey = try dvdDecryptor!.getTitleKey(titleNumber: title.number, startSector: title.startSector)
        
        // Create output filename
        let outputFileName = "DVD_Title_\(String(format: "%02d", title.number))_\(title.formattedDuration.replacingOccurrences(of: ":", with: "-")).mkv"
        let outputPath = configuration.outputDirectory.appending("/\(outputFileName)")
        
        // Extract and decrypt video data
        let tempVideoFile = try extractAndDecryptDVDTitle(title, titleKey: titleKey)
        
        // Convert to MKV
        try convertToMKV(
            inputFile: tempVideoFile,
            outputFile: outputPath,
            mediaItem: .dvdTitle(title),
            configuration: configuration,
            itemIndex: titleIndex,
            totalItems: totalTitles
        )
        
        // Cleanup temp file
        try? FileManager.default.removeItem(atPath: tempVideoFile)
    }
    
    private func extractAndDecryptDVDTitle(_ title: DVDTitle, titleKey: DVDDecryptor.CSSKey) throws -> String {
        let tempDirectory = NSTemporaryDirectory()
        let tempFileName = "temp_dvd_title_\(title.number).vob"
        let tempFilePath = tempDirectory.appending(tempFileName)
        
        guard let outputHandle = FileHandle(forWritingAtPath: tempFilePath) ??
              {
                  FileManager.default.createFile(atPath: tempFilePath, contents: nil)
                  return FileHandle(forWritingAtPath: tempFilePath)
              }() else {
            throw MediaRipperError.failedToCreateTempFile
        }
        
        defer { outputHandle.closeFile() }
        
        // Process each VOB file for this title
        for vobFile in title.vobFiles {
            try processDVDVOBFile(vobFile, title: title, titleKey: titleKey, outputHandle: outputHandle)
        }
        
        return tempFilePath
    }
    
    private func processDVDVOBFile(_ vobFilePath: String, title: DVDTitle, titleKey: DVDDecryptor.CSSKey, outputHandle: FileHandle) throws {
        guard let inputHandle = FileHandle(forReadingAtPath: vobFilePath) else {
            throw MediaRipperError.failedToReadFile
        }
        
        defer { inputHandle.closeFile() }
        
        let fileSize = inputHandle.seekToEndOfFile()
        inputHandle.seek(toFileOffset: 0)
        
        let sectorSize = 2048
        var currentSector: UInt32 = 0
        var processedBytes: UInt64 = 0
        
        while processedBytes < fileSize {
            if shouldCancel {
                throw MediaRipperError.cancelled
            }
            
            let sectorData = inputHandle.readData(ofLength: sectorSize)
            if sectorData.isEmpty { break }
            
            // Decrypt sector if needed
            let decryptedData = try dvdDecryptor!.decryptSector(
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
                    self.delegate?.ripperDidUpdateProgress(progress * 0.5, currentItem: .dvdTitle(title), totalItems: 1)
                }
            }
        }
    }
    
    // MARK: - Blu-ray Ripping
    
    private func performBluRayRipping(blurayPath: String, configuration: RippingConfiguration) throws {
        // Step 1: Parse Blu-ray structure
        delegate?.ripperDidUpdateStatus("Analyzing Blu-ray structure...")
        blurayParser = BluRayStructureParser(blurayPath: blurayPath)
        let playlists = try blurayParser!.parseBluRayStructure()
        
        guard !playlists.isEmpty else {
            throw MediaRipperError.noPlaylistsFound
        }
        
        // Step 2: Initialize Blu-ray decryptor
        delegate?.ripperDidUpdateStatus("Initializing Blu-ray AACS decryption...")
        let devicePath = findBluRayDevice(blurayPath: blurayPath)
        blurayDecryptor = BluRayDecryptor(devicePath: devicePath)
        try blurayDecryptor!.initializeDevice()
        
        // Step 3: Determine which playlists to rip
        let playlistsToRip = filterPlaylistsToRip(playlists: playlists, selectedTitles: configuration.selectedTitles)
        delegate?.ripperDidUpdateProgress(0.0, currentItem: nil, totalItems: playlistsToRip.count)
        
        // Step 4: Rip each playlist
        for (index, playlist) in playlistsToRip.enumerated() {
            if shouldCancel {
                throw MediaRipperError.cancelled
            }
            
            delegate?.ripperDidUpdateStatus("Ripping Blu-ray playlist \(playlist.number) (\(playlist.formattedDuration))...")
            try ripBluRayPlaylist(playlist, configuration: configuration, playlistIndex: index, totalPlaylists: playlistsToRip.count)
        }
    }
    
    private func ripBluRayPlaylist(_ playlist: BluRayPlaylist, configuration: RippingConfiguration, playlistIndex: Int, totalPlaylists: Int) throws {
        // Get title key for decryption
        let titleKey = try blurayDecryptor!.getTitleKey(titleNumber: playlist.number, startSector: 0)
        
        // Create output filename
        let outputFileName = "BluRay_Playlist_\(String(format: "%05d", playlist.number))_\(playlist.formattedDuration.replacingOccurrences(of: ":", with: "-")).mkv"
        let outputPath = configuration.outputDirectory.appending("/\(outputFileName)")
        
        // Extract and decrypt video data
        let tempVideoFile = try extractAndDecryptBluRayPlaylist(playlist, titleKey: titleKey)
        
        // Convert to MKV
        try convertToMKV(
            inputFile: tempVideoFile,
            outputFile: outputPath,
            mediaItem: .blurayPlaylist(playlist),
            configuration: configuration,
            itemIndex: playlistIndex,
            totalItems: totalPlaylists
        )
        
        // Cleanup temp file
        try? FileManager.default.removeItem(atPath: tempVideoFile)
    }
    
    private func extractAndDecryptBluRayPlaylist(_ playlist: BluRayPlaylist, titleKey: BluRayDecryptor.AACSKey) throws -> String {
        let tempDirectory = NSTemporaryDirectory()
        let tempFileName = "temp_bluray_playlist_\(playlist.number).m2ts"
        let tempFilePath = tempDirectory.appending(tempFileName)
        
        guard let outputHandle = FileHandle(forWritingAtPath: tempFilePath) ??
              {
                  FileManager.default.createFile(atPath: tempFilePath, contents: nil)
                  return FileHandle(forWritingAtPath: tempFilePath)
              }() else {
            throw MediaRipperError.failedToCreateTempFile
        }
        
        defer { outputHandle.closeFile() }
        
        // Get stream files for this playlist
        let streamFiles = blurayParser!.getStreamFiles(for: playlist)
        
        // Process each stream file for this playlist
        for streamFile in streamFiles {
            try processBluRayStreamFile(streamFile, playlist: playlist, titleKey: titleKey, outputHandle: outputHandle)
        }
        
        return tempFilePath
    }
    
    private func processBluRayStreamFile(_ streamFilePath: String, playlist: BluRayPlaylist, titleKey: BluRayDecryptor.AACSKey, outputHandle: FileHandle) throws {
        guard let inputHandle = FileHandle(forReadingAtPath: streamFilePath) else {
            throw MediaRipperError.failedToReadFile
        }
        
        defer { inputHandle.closeFile() }
        
        let fileSize = inputHandle.seekToEndOfFile()
        inputHandle.seek(toFileOffset: 0)
        
        let sectorSize = 2048
        var currentSector: UInt32 = 0
        var processedBytes: UInt64 = 0
        
        while processedBytes < fileSize {
            if shouldCancel {
                throw MediaRipperError.cancelled
            }
            
            let sectorData = inputHandle.readData(ofLength: sectorSize)
            if sectorData.isEmpty { break }
            
            // Decrypt sector if needed
            let decryptedData = try blurayDecryptor!.decryptSector(
                data: sectorData,
                sector: currentSector,
                titleNumber: playlist.number
            )
            
            outputHandle.write(decryptedData)
            
            currentSector += 1
            processedBytes += UInt64(sectorData.count)
            
            // Update progress occasionally
            if currentSector % 100 == 0 {
                let progress = Double(processedBytes) / Double(fileSize)
                DispatchQueue.main.async {
                    self.delegate?.ripperDidUpdateProgress(progress * 0.5, currentItem: .blurayPlaylist(playlist), totalItems: 1)
                }
            }
        }
    }
    
    // MARK: - Common Operations
    
    enum MediaItem {
        case dvdTitle(DVDTitle)
        case blurayPlaylist(BluRayPlaylist)
    }
    
    private func convertToMKV(inputFile: String, outputFile: String, mediaItem: MediaItem,
                             configuration: RippingConfiguration, itemIndex: Int, totalItems: Int) throws {
        
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
        if configuration.includeChapters {
            let chaptersFile = try createChaptersFile(for: mediaItem)
            if !chaptersFile.isEmpty {
                ffmpegArgs.append(contentsOf: ["-f", "ffmetadata", "-i", chaptersFile])
                defer { try? FileManager.default.removeItem(atPath: chaptersFile) }
            }
        }
        
        // Add metadata based on media type
        switch mediaItem {
        case .dvdTitle(let title):
            ffmpegArgs.append(contentsOf: [
                "-metadata", "title=DVD Title \(title.number)",
                "-metadata", "duration=\(title.formattedDuration)",
                "-metadata", "source_type=DVD"
            ])
        case .blurayPlaylist(let playlist):
            ffmpegArgs.append(contentsOf: [
                "-metadata", "title=Blu-ray Playlist \(playlist.number)",
                "-metadata", "duration=\(playlist.formattedDuration)",
                "-metadata", "source_type=Blu-ray"
            ])
        }
        
        ffmpegArgs.append(outputFile)
        
        // Execute FFmpeg
        try executeFFmpeg(args: ffmpegArgs, itemIndex: itemIndex, totalItems: totalItems)
    }
    
    private func createChaptersFile(for mediaItem: MediaItem) throws -> String {
        let tempDirectory = NSTemporaryDirectory()
        var chaptersFileName = ""
        var chaptersContent = ";FFMETADATA1\n"
        
        switch mediaItem {
        case .dvdTitle(let title):
            chaptersFileName = "chapters_dvd_\(title.number).txt"
            
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
            
        case .blurayPlaylist(let playlist):
            chaptersFileName = "chapters_bluray_\(playlist.number).txt"
            
            for (index, mark) in playlist.marks.enumerated() {
                if mark.type == 1 { // Chapter mark
                    let startTime = Int(mark.time / 45) // Convert from 45kHz to milliseconds
                    let endTime = index < playlist.marks.count - 1 ? 
                        Int(playlist.marks[index + 1].time / 45) : 
                        Int(playlist.duration * 1000)
                    
                    chaptersContent += """
                    [CHAPTER]
                    TIMEBASE=1/1000
                    START=\(startTime)
                    END=\(endTime)
                    title=Chapter \(index + 1)
                    
                    """
                }
            }
        }
        
        if chaptersContent == ";FFMETADATA1\n" {
            return "" // No chapters to add
        }
        
        let chaptersFilePath = tempDirectory.appending(chaptersFileName)
        try chaptersContent.write(toFile: chaptersFilePath, atomically: true, encoding: .utf8)
        return chaptersFilePath
    }
    
    private func executeFFmpeg(args: [String], itemIndex: Int, totalItems: Int) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/local/bin/ffmpeg")
        process.arguments = args
        
        // Set up progress monitoring
        let pipe = Pipe()
        process.standardError = pipe
        
        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if let output = String(data: data, encoding: .utf8) {
                self.parseFFmpegProgress(output, itemIndex: itemIndex, totalItems: totalItems)
            }
        }
        
        try process.run()
        process.waitUntilExit()
        
        pipe.fileHandleForReading.readabilityHandler = nil
        
        guard process.terminationStatus == 0 else {
            throw MediaRipperError.conversionFailed
        }
    }
    
    private func parseFFmpegProgress(_ output: String, itemIndex: Int, totalItems: Int) {
        // Parse FFmpeg progress output
        let lines = output.components(separatedBy: .newlines)
        
        for line in lines {
            if line.contains("time=") {
                // Extract time progress
                let components = line.components(separatedBy: " ")
                for component in components {
                    if component.hasPrefix("time=") {
                        // Convert time to progress percentage
                        let baseProgress = Double(itemIndex) / Double(totalItems)
                        let itemProgress = 0.5 + 0.5 * 0.5 // Simplified progress calculation
                        
                        DispatchQueue.main.async {
                            self.delegate?.ripperDidUpdateProgress(baseProgress + itemProgress / Double(totalItems), currentItem: nil, totalItems: totalItems)
                        }
                        break
                    }
                }
            }
        }
    }
    
    // MARK: - Utility Functions
    
    private func filterTitlesToRip(titles: [DVDTitle], selectedTitles: [Int]) -> [DVDTitle] {
        if selectedTitles.isEmpty {
            return titles
        } else {
            return titles.filter { selectedTitles.contains($0.number) }
        }
    }
    
    private func filterPlaylistsToRip(playlists: [BluRayPlaylist], selectedTitles: [Int]) -> [BluRayPlaylist] {
        if selectedTitles.isEmpty {
            return playlists
        } else {
            return playlists.filter { selectedTitles.contains($0.number) }
        }
    }
    
    private func findDVDDevice(dvdPath: String) -> String {
        // Find the actual device path for the DVD
        return dvdPath
    }
    
    private func findBluRayDevice(blurayPath: String) -> String {
        // Find the actual device path for the Blu-ray
        return blurayPath
    }
    
    private func mediaTypeString(_ type: MediaType) -> String {
        switch type {
        case .dvd: return "DVD"
        case .bluray: return "Blu-ray"
        case .unknown: return "Unknown"
        }
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

protocol MediaRipperDelegate: AnyObject {
    func ripperDidStart()
    func ripperDidUpdateStatus(_ status: String)
    func ripperDidUpdateProgress(_ progress: Double, currentItem: MediaRipper.MediaItem?, totalItems: Int)
    func ripperDidComplete()
    func ripperDidFail(with error: Error)
}

// MARK: - Error Types

enum MediaRipperError: Error {
    case alreadyRipping
    case unsupportedMediaType
    case noTitlesFound
    case noPlaylistsFound
    case failedToCreateTempFile
    case failedToReadFile
    case conversionFailed
    case cancelled
    
    var localizedDescription: String {
        switch self {
        case .alreadyRipping:
            return "Already ripping"
        case .unsupportedMediaType:
            return "Unsupported media type"
        case .noTitlesFound:
            return "No titles found on DVD"
        case .noPlaylistsFound:
            return "No playlists found on Blu-ray"
        case .failedToCreateTempFile:
            return "Failed to create temporary file"
        case .failedToReadFile:
            return "Failed to read media file"
        case .conversionFailed:
            return "Media conversion failed"
        case .cancelled:
            return "Operation cancelled"
        }
    }
}
