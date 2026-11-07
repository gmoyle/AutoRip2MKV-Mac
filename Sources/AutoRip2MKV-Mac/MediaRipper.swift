import Foundation
import AVFoundation

/// Unified media ripper that handles both DVD and Blu-ray formats with native decryption
/// Implementation details are in separate extension files for better organization
class MediaRipper {
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
    weak var conversionQueue: ConversionQueue?

    var dvdParser: DVDStructureParser?
    var blurayParser: BluRayStructureParser?
    var dvdDecryptor: DVDDecryptor?
    var blurayDecryptor: BluRayDecryptor?
    var makemkvBackend: MakeMKVBackend?
    var isRipping = false
    var shouldCancel = false
    /// True while sectors are being read off the disc. While set, ffmpeg's
    /// (much slower) encode-time progress is suppressed so the UI shows disc
    /// read progress; once feeding ends, encode progress takes over.
    var isFeedingDisc = false
    var currentMediaType: MediaType = .unknown
    var activeFFmpegProcess: Process?
    /// Encodes prepared while the disc was read, run by the queue after eject.
    /// Each reads a decrypted title from local staging, so the drive is freed as
    /// soon as reading finishes and the next disc can rip while these encode.
    var pendingEncodes: [PendingEncode] = []
    /// Finished files written directly by a backend with no separate encode phase
    /// (MakeMKV). The queue records these the same way it records finished encodes.
    var directOutputFiles: [String] = []

    /// Set by rippers whose files land only after the encode phase (DVD), so
    /// the queue can route the finished folder to the Movies/TV root once the
    /// encodes are in place. Blu-ray routes itself and leaves this nil.
    struct PendingRoute {
        let folderPath: String
        let discName: String
        let discIdentity: String?
        let titleDurationsSeconds: [Int]
    }
    var routeAfterEncodes: PendingRoute?

    /// Stop any running encode and discard all staging files (decrypted titles
    /// and partial encodes). Used before a retry re-reads the disc and when a job
    /// is abandoned, so nothing is left running or filling the staging folder.
    func discardPendingEncodes() {
        for encode in pendingEncodes {
            if let process = encode.process, process.isRunning {
                process.terminate()
                process.waitUntilExit()
            }
            try? FileManager.default.removeItem(atPath: encode.sourcePath)
            try? FileManager.default.removeItem(atPath: encode.stagingPath)
        }
        pendingEncodes.removeAll()
    }

    /// Run one prepared encode to completion (blocking). Returns true when ffmpeg
    /// exits cleanly. The decrypted source is deleted either way; on success the
    /// encoded file is left at `encode.stagingPath` for the caller to move.
    func runEncode(_ encode: PendingEncode) -> Bool {
        defer { try? FileManager.default.removeItem(atPath: encode.sourcePath) }
        guard !shouldCancel else { return false }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: encode.ffmpegPath)
        process.arguments = encode.arguments
        let stderrPipe = Pipe()
        process.standardError = stderrPipe
        process.standardOutput = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            Logger.shared.logError(error, context: "Failed to launch ffmpeg for title \(encode.titleNumber)")
            return false
        }
        encode.process = process
        activeFFmpegProcess = process
        delegate?.mediaRipperDidUpdateStatus("Encoding title \(encode.titleNumber) (\(encode.itemIndex + 1) of \(encode.totalItems))...")

        // Drains stderr (progress lines) until ffmpeg exits and closes it.
        let stderrTail = monitorFFmpegProgress(pipe: stderrPipe, mediaItem: encode.mediaItem,
                                               itemIndex: encode.itemIndex, totalItems: encode.totalItems)
        process.waitUntilExit()
        activeFFmpegProcess = nil
        encode.process = nil
        if process.terminationStatus != 0 && !shouldCancel {
            Logger.shared.log(
                "ffmpeg exited \(process.terminationStatus) for title \(encode.titleNumber) (\(encode.ffmpegPath))\n"
                    + "  args: \(encode.arguments.joined(separator: " "))\n"
                    + stderrTail.map { "  | \($0)" }.joined(separator: "\n"),
                level: .error, category: .general)
        }
        return process.terminationStatus == 0
    }

    /// Local (non-iCloud-synced) staging path for an in-progress encode. Encoding
    /// directly into the output directory corrupts rips when that directory is
    /// synced (iCloud restores stale versions of files it saw mid-write); the
    /// finished file is moved into place atomically on success.
    func encodingStagingPath(for outputPath: String) -> String {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
            .first?.path ?? NSTemporaryDirectory()
        let stagingDir = base.appending("/AutoRip2MKV/encoding")
        try? FileManager.default.createDirectory(atPath: stagingDir, withIntermediateDirectories: true)
        return stagingDir.appending("/\((outputPath as NSString).lastPathComponent)")
    }

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
    // Deinterlace frames flagged as interlaced (bwdif); progressive frames pass through
    var autoDeinterlace: Bool = true
    // Resolved "Movie (Year)" title; when set, output uses Plex-style naming:
    // <output>/<Movie (Year)>/<Movie (Year)>.mkv
    var plexName: String? = nil
    // Encode H.264/HEVC with Apple VideoToolbox instead of the software encoder
    // (much faster; falls back to software where VT can't honor the settings)
    var hardwareAcceleration: Bool = false
    // Rip bonus features too, not just the main feature (SettingsManager.ripBonusFeatures)
    var ripBonusFeatures: Bool = false

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

    deinit {
        activeFFmpegProcess?.terminate()
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
            delegate?.mediaRipperDidFail(with: MediaRipperError.alreadyRipping)
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
                    self.delegate?.mediaRipperDidFail(with: error)
                    self.isRipping = false
                }
            }
        }
    }

    /// Cancel the current ripping operation
    func cancelRipping() {
        Logger.shared.log("Cancelling ripping operation", level: .info, category: .general)
        shouldCancel = true
        activeFFmpegProcess?.terminate()
        activeFFmpegProcess = nil
        makemkvBackend?.terminate()
        // The queue checks shouldCancel before starting each remaining encode.
        for encode in pendingEncodes where encode.process?.isRunning == true {
            encode.process?.terminate()
        }
    }

    /// Check if currently ripping
    var isCurrentlyRipping: Bool {
        return isRipping
    }

    // MARK: - Private Implementation

    /// Runs the rip for one disc. Failures are reported to the delegate exactly
    /// once, by the caller (startRipping), after all retries are
    /// exhausted — the queue treats the first mediaRipperDidFail as "this ripper is
    /// done with the drive", so an early report would let the next job start while
    /// retries are still reading the disc.
    private func performRipping(mediaPath: String, configuration: RippingConfiguration) throws {
        delegate?.mediaRipperDidStart()

        // Step 1: Detect media type
        currentMediaType = configuration.mediaType ?? detectMediaType(path: mediaPath)

        delegate?.mediaRipperDidUpdateStatus("Detected \(mediaTypeString(currentMediaType)) media")

        switch currentMediaType {
        case .dvd, .ultraHDDVD:
            try withRetries(label: "DVD", category: .dvdRipping, delaySeconds: 5) {
                try performDVDRipping(dvdPath: mediaPath, configuration: configuration)
            }
        case .bluray, .bluray4K:
            // Prefer MakeMKV for Blu-ray: it handles AACS/BD+ with its own keys.
            // The built-in libaacs path only works with a user-supplied key
            // database and is kept as an explicit fallback.
            if SettingsManager.shared.useMakeMKVForBluRay && MakeMKVBackend.isInstalled {
                try performBluRayRippingWithMakeMKV(blurayPath: mediaPath, configuration: configuration)
            } else {
                if SettingsManager.shared.useMakeMKVForBluRay {
                    delegate?.mediaRipperDidUpdateStatus(
                        "MakeMKV not found — falling back to libaacs (needs an AACS key database).")
                }
                try withRetries(label: "Blu-ray", category: .blurayRipping, delaySeconds: 0) {
                    try performBluRayRipping(blurayPath: mediaPath, configuration: configuration)
                }
            }
        case .hddvd:
            try withRetries(label: "HD DVD", category: .general, delaySeconds: 0) {
                try performHDDVDRippingWorkflow(hddvdPath: mediaPath, configuration: configuration)
            }
        case .unknown:
            throw MediaRipperError.unsupportedMediaType
        }

        // DVD ripping fires mediaRipperDidComplete() itself (after last sector is fed,
        // before encoding finishes) so the disc can be ejected immediately.
        // Other media types complete synchronously and need the signal here.
        if currentMediaType != .dvd && currentMediaType != .ultraHDDVD {
            Logger.shared.log("Ripping process completed successfully", level: .info, category: .general)
            DispatchQueue.main.async {
                self.delegate?.mediaRipperDidComplete()
                self.isRipping = false
            }
        }
    }
}

extension MediaRipper {
    /// Run `attempt` up to 3 times. Cancellation is never retried, and a pause
    /// between attempts gives transient drive contention (another process
    /// grabbing the drive, a volume remount) a chance to clear.
    func withRetries(label: String, category: Logger.Category, delaySeconds: TimeInterval,
                     _ attempt: () throws -> Void) throws {
        let maxRetries = 3
        for attemptNumber in 1...maxRetries {
            do {
                try attempt()
                return
            } catch {
                Logger.shared.logError(error, context: "\(label) structure/decryption failed (attempt \(attemptNumber))",
                                       category: category)
                if shouldCancel || isCancellation(error) { throw MediaRipperError.cancelled }
                // A licensing refusal won't change on retry.
                if case MakeMKVBackend.MakeMKVError.registrationRequired = error { throw error }
                if attemptNumber == maxRetries { throw error }
                let pause = delaySeconds > 0 ? " Retrying in \(Int(delaySeconds))s..." : " Retrying..."
                delegate?.mediaRipperDidUpdateStatus("\(label) parse/decryption failed (attempt \(attemptNumber)).\(pause)")
                if delaySeconds > 0 { Thread.sleep(forTimeInterval: delaySeconds) }
                if shouldCancel { throw MediaRipperError.cancelled }
            }
        }
    }

    private func isCancellation(_ error: Error) -> Bool {
        if case MediaRipperError.cancelled = error { return true }
        if case MakeMKVBackend.MakeMKVError.cancelled = error { return true }
        return false
    }
}

/// An ffmpeg encode of one decrypted title, prepared while the disc is read and
/// run after it is ejected.
final class PendingEncode {
    let ffmpegPath: String
    let arguments: [String]
    /// Decrypted title read off the disc into local staging (ffmpeg's input).
    let sourcePath: String
    /// Final location; the queue moves the finished encode here.
    let outputPath: String
    /// Where ffmpeg writes the encode (local, never cloud-synced).
    let stagingPath: String
    let titleNumber: Int
    let mediaItem: MediaRipper.MediaItem
    let itemIndex: Int
    let totalItems: Int
    /// Set while the encode runs, for cancellation.
    var process: Process?

    init(ffmpegPath: String, arguments: [String], sourcePath: String, outputPath: String,
         stagingPath: String, titleNumber: Int, mediaItem: MediaRipper.MediaItem,
         itemIndex: Int, totalItems: Int) {
        self.ffmpegPath = ffmpegPath
        self.arguments = arguments
        self.sourcePath = sourcePath
        self.outputPath = outputPath
        self.stagingPath = stagingPath
        self.titleNumber = titleNumber
        self.mediaItem = mediaItem
        self.itemIndex = itemIndex
        self.totalItems = totalItems
    }
}

// MARK: - Delegate Protocol

protocol MediaRipperDelegate: AnyObject {
    func mediaRipperDidStart()
    func mediaRipperDidUpdateStatus(_ status: String)
    func mediaRipperDidUpdateProgress(_ progress: Double, currentItem: MediaRipper.MediaItem?, totalItems: Int)
    func mediaRipperDidComplete()
    func mediaRipperDidFail(with error: Error)
}

// MARK: - Error Types

enum MediaRipperError: LocalizedError {
    case alreadyRipping
    case unsupportedMediaType
    case noTitlesFound
    case fileCreationFailed
    case fileNotFound
    case conversionFailed
    case ffmpegNotFound
    case cancelled
    case deviceNotFound

    var errorDescription: String? {
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
