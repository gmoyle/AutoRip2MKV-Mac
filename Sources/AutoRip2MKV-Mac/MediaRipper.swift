import Foundation
import AVFoundation

/// Unified media ripper that handles both DVD and Blu-ray formats with native decryption
/// Implementation details are in separate extension files for better organization
class MediaRipper {
    /// Performs HD DVD ripping workflow (simulated)
    func performHDDVDRipping(hddvdPath: String, configuration: RippingConfiguration) throws {
        Logger.shared.log("Starting HD DVD ripping for path: \(hddvdPath)", level: .info, category: .general)
        // Simulate structure parsing and analysis
        let parser = HDDVDStructureParser()
        let structure = try parser.parseStructure(at: hddvdPath)
        guard let mainTitleIndex = structure.mainTitleIndex, structure.titles.indices.contains(mainTitleIndex) else {
            throw MediaRipperError.unsupportedMediaType
        }
        let mainTitle = structure.titles[mainTitleIndex]
        Logger.shared.log("HD DVD main title: \(mainTitle.name), duration: \(mainTitle.durationSeconds)s, chapters: \(mainTitle.chapters)", level: .info, category: .general)
        // Simulate ripping process
        delegate?.ripperDidUpdateStatus("Ripping HD DVD: \(mainTitle.name)")
        // ...actual ripping logic would go here...
        Logger.shared.log("HD DVD ripping completed for \(mainTitle.name)", level: .info, category: .general)
    }

    // Media type detection
    enum MediaType {
    case dvd
    case ultraHDDVD
    case bluray
    case bluray4K
    case hddvd
    case unknown

        var folderName: String {
            switch self {
            case .dvd: return "DVD"
            case .ultraHDDVD: return "Ultra_HD_DVD"
            case .bluray: return "Blu-ray"
            case .bluray4K: return "4K_Blu-ray"
            case .hddvd: return "HD_DVD"
            case .unknown: return "Unknown_Media"
            }
        }
    }

    // Progress and status tracking
    weak var delegate: MediaRipperDelegate?

    var dvdParser: DVDStructureParser?
    var blurayParser: BluRayStructureParser?
    var dvdDecryptor: DVDDecryptor?
    var blurayDecryptor: BluRayDecryptor?
    var isRipping = false
    var shouldCancel = false
    var currentMediaType: MediaType = .unknown

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
            case h264, h265, av1, vp9
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
        Logger.shared.log("MediaRipper initialized", level: .info, category: .general)
    }

    // MARK: - Public Interface

    /// Detect media type from directory structure
    func detectMediaType(path: String) -> MediaType {
        let videoTSPath = path.appending("/VIDEO_TS")
        let bdmvPath = path.appending("/BDMV")

        if FileManager.default.fileExists(atPath: bdmvPath) {
            // Check if it's 4K Blu-ray by looking for UHD indicators
            if isUltraHDBluRay(bdmvPath: bdmvPath) {
                return .bluray4K
            }
            return .bluray
        } else if FileManager.default.fileExists(atPath: videoTSPath) {
            // Check if it's Ultra HD DVD
            if isUltraHDDVD(videoTSPath: videoTSPath) {
                return .ultraHDDVD
            }
            return .dvd
        }

        return .unknown
    }

    /// Start the media ripping process
    func startRipping(mediaPath: String, configuration: RippingConfiguration) {
        guard !isRipping else {
            Logger.shared.logError(MediaRipperError.alreadyRipping, context: "Attempted to start ripping while already in progress")
            delegate?.ripperDidFail(with: MediaRipperError.alreadyRipping)
            return
        }

        Logger.shared.log("Starting ripping process for media at: \(mediaPath)", level: .info, category: .general)
        isRipping = true
        shouldCancel = false

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try self.performRipping(mediaPath: mediaPath, configuration: configuration)
            } catch {
                Logger.shared.logError(error, context: "MediaRipper failed during ripping process")
                DispatchQueue.main.async {
                    self.delegate?.ripperDidFail(with: error)
                    self.isRipping = false
                }
            }
        }
    }

    /// Cancel the current ripping operation
    func cancelRipping() {
        Logger.shared.log("Cancelling ripping operation", level: .info, category: .general)
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
        Logger.shared.log("Detected media type: \(mediaTypeString(currentMediaType))", level: .info, category: .general)

        delegate?.ripperDidUpdateStatus("Detected \(mediaTypeString(currentMediaType)) media")

        switch currentMediaType {
        case .dvd, .ultraHDDVD:
            try performDVDRipping(dvdPath: mediaPath, configuration: configuration)
        case .bluray, .bluray4K:
            try performBluRayRipping(blurayPath: mediaPath, configuration: configuration)
        case .hddvd:
            try performHDDVDRipping(hddvdPath: mediaPath, configuration: configuration)
        case .unknown:
            throw MediaRipperError.unsupportedMediaType
        }

        // Complete
        Logger.shared.log("Ripping process completed successfully", level: .info, category: .general)
        DispatchQueue.main.async {
            self.delegate?.ripperDidComplete()
            self.isRipping = false
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
    case fileCreationFailed
    case fileNotFound
    case conversionFailed
    case ffmpegNotFound
    case cancelled
    case deviceNotFound

    var localizedDescription: String {
        switch self {
        case .alreadyRipping:
            return "A ripping operation is already in progress"
        case .unsupportedMediaType:
            return "Unsupported media type"
        case .noTitlesFound:
            return "No titles found on the media"
        case .fileCreationFailed:
            return "Failed to create temporary file"
        case .fileNotFound:
            return "Required file not found"
        case .conversionFailed:
            return "Video conversion failed"
        case .ffmpegNotFound:
            return "FFmpeg not found"
        case .cancelled:
            return "Operation was cancelled"
        case .deviceNotFound:
            return "DVD/Blu-ray device not found"
        }
    }
}
