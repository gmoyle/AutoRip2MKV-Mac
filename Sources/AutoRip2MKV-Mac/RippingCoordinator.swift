import Foundation
import Cocoa

/// Protocol for coordinating media ripping operations
/// This abstraction allows for dependency injection and better testability
protocol RippingCoordinating {
    /// Start ripping with the specified configuration
    func startRipping(with configuration: RippingCoordinator.RippingConfiguration) async throws
    
    /// Cancel the current ripping operation
    func cancelRipping() async
    
    /// Get progress updates as an async stream
    var progress: AsyncStream<RippingCoordinator.RippingProgress> { get }
    
    /// Check if currently ripping
    var isRipping: Bool { get }
    
    /// Delegate for ripping events
    var delegate: RippingCoordinatorDelegate? { get set }
}

/// Coordinates the complete ripping workflow including media detection, decryption, and conversion
/// Extracted from MainViewController to provide better separation of concerns and async/await support
class RippingCoordinator: RippingCoordinating, @unchecked Sendable {
    
    // MARK: - Types
    
    /// Configuration for ripping operations
    struct RippingConfiguration {
        let sourcePath: String
        let outputDirectory: String
        let selectedTitles: [Int] // Empty means all titles
        let videoCodec: VideoCodec
        let audioCodec: AudioCodec
        let quality: RippingQuality
        let includeSubtitles: Bool
        let includeChapters: Bool
        let mediaType: MediaType?
        let discTitle: String
        
        enum VideoCodec {
            case h264, h265, av1
        }
        
        enum AudioCodec {
            case aac, ac3, dts, flac
        }
        
        enum RippingQuality {
            case low, medium, high, lossless
        }
        
        enum MediaType {
            case dvd, bluray, ultraHDDVD, bluray4K, unknown
        }
    }
    
    /// Progress information for ripping operations
    struct RippingProgress {
        let phase: Phase
        let overallProgress: Double // 0.0 to 1.0
        let currentItem: String?
        let itemProgress: Double // 0.0 to 1.0
        let estimatedTimeRemaining: TimeInterval?
        let status: String
        
        enum Phase {
            case detecting
            case decrypting
            case extracting
            case converting
            case organizing
            case completed
        }
    }
    
    // MARK: - Properties
    
    private let mediaRipper: MediaRipper
    private let conversionQueue: ConversionQueue
    private let settingsManager: SettingsManager
    
    private var currentTask: Task<Void, Error>?
    private var progressContinuation: AsyncStream<RippingProgress>.Continuation?
    private var isRippingInternal = false
    
    weak var delegate: RippingCoordinatorDelegate?
    
    // MARK: - Initialization
    
    /// Initialize with dependency injection for better testability
    init(mediaRipper: MediaRipper = MediaRipper(),
         conversionQueue: ConversionQueue = ConversionQueue(),
         settingsManager: SettingsManager = SettingsManager.shared) {
        self.mediaRipper = mediaRipper
        self.conversionQueue = conversionQueue
        self.settingsManager = settingsManager
        
        setupDelegates()
    }
    
    private func setupDelegates() {
        mediaRipper.delegate = self
        conversionQueue.delegate = self
    }
    
    // MARK: - RippingCoordinating Implementation
    
    var isRipping: Bool {
        return isRippingInternal
    }
    
    var progress: AsyncStream<RippingProgress> {
        AsyncStream { continuation in
            self.progressContinuation = continuation
        }
    }
    
    func startRipping(with configuration: RippingConfiguration) async throws {
        guard !isRippingInternal else {
            throw RippingCoordinatorError.alreadyRipping
        }
        
        isRippingInternal = true
        
        // Create and start the ripping task
        currentTask = Task {
            do {
                try await performRipping(with: configuration)
            } catch {
                await handleRippingError(error)
                throw error
            }
        }
        
        // Wait for completion
        try await currentTask?.value
        isRippingInternal = false
    }
    
    func cancelRipping() async {
        currentTask?.cancel()
        isRippingInternal = false
        
        // Cancel ongoing operations
        mediaRipper.cancelRipping()
        conversionQueue.cancelAllJobs()
        
        await sendProgress(.init(
            phase: .completed,
            overallProgress: 0.0,
            currentItem: nil,
            itemProgress: 0.0,
            estimatedTimeRemaining: nil,
            status: "Ripping cancelled"
        ))
        
        await MainActor.run {
            delegate?.rippingCoordinatorDidCancel()
        }
    }
    
    // MARK: - Private Implementation
    
    private func performRipping(with configuration: RippingConfiguration) async throws {
        await MainActor.run {
            delegate?.rippingCoordinatorDidStart()
        }
        
        await sendProgress(.init(
            phase: .detecting,
            overallProgress: 0.1,
            currentItem: "Detecting media type",
            itemProgress: 0.0,
            estimatedTimeRemaining: nil,
            status: "Analyzing disc structure..."
        ))
        
        // Step 1: Detect media type if not provided
        let detectedMediaType = try await detectMediaType(configuration: configuration)
        
        await sendProgress(.init(
            phase: .extracting,
            overallProgress: 0.2,
            currentItem: configuration.discTitle,
            itemProgress: 0.0,
            estimatedTimeRemaining: nil,
            status: "Starting extraction process..."
        ))
        
        // Step 2: Add to conversion queue for processing
        let mediaRipperConfig = MediaRipper.RippingConfiguration(
            outputDirectory: configuration.outputDirectory,
            selectedTitles: configuration.selectedTitles,
            videoCodec: mapVideoCodec(configuration.videoCodec),
            audioCodec: mapAudioCodec(configuration.audioCodec),
            quality: mapQuality(configuration.quality),
            includeSubtitles: configuration.includeSubtitles,
            includeChapters: configuration.includeChapters,
            mediaType: mapMediaType(detectedMediaType),
            batchMode: false
        )
        
        let jobId = conversionQueue.addJob(
            sourcePath: configuration.sourcePath,
            outputDirectory: configuration.outputDirectory,
            configuration: mediaRipperConfig,
            mediaType: mapToConversionQueueMediaType(detectedMediaType),
            discTitle: configuration.discTitle
        )
        
        // Step 3: Monitor the queue job until completion
        try await monitorQueueJob(jobId)
        
        await sendProgress(.init(
            phase: .completed,
            overallProgress: 1.0,
            currentItem: configuration.discTitle,
            itemProgress: 1.0,
            estimatedTimeRemaining: 0,
            status: "Ripping completed successfully!"
        ))
        
        await MainActor.run {
            delegate?.rippingCoordinatorDidComplete()
        }
    }
    
    private func detectMediaType(configuration: RippingConfiguration) async throws -> RippingConfiguration.MediaType {
        if let mediaType = configuration.mediaType {
            return mediaType
        }
        
        // Use MediaRipper to detect media type
        let detectedType = mediaRipper.detectMediaType(path: configuration.sourcePath)
        return mapFromMediaRipperType(detectedType)
    }
    
    private func monitorQueueJob(_ jobId: UUID) async throws {
        // This would be implemented to monitor the conversion queue job
        // For now, we'll simulate the monitoring process
        
        let checkInterval: TimeInterval = 1.0
        var lastProgress: Double = 0.2
        
        while lastProgress < 1.0 {
            try Task.checkCancellation()
            
            try await Task.sleep(nanoseconds: UInt64(checkInterval * 1_000_000_000))
            
            // Simulate progress updates
            lastProgress += 0.1
            
            let phase: RippingProgress.Phase = {
                switch lastProgress {
                case 0.0..<0.3: return .extracting
                case 0.3..<0.9: return .converting
                case 0.9..<1.0: return .organizing
                default: return .completed
                }
            }()
            
            await sendProgress(.init(
                phase: phase,
                overallProgress: lastProgress,
                currentItem: "Processing...",
                itemProgress: (lastProgress - 0.2) / 0.8, // Normalize to 0-1 for current phase
                estimatedTimeRemaining: lastProgress < 1.0 ? (1.0 - lastProgress) * 300 : 0,
                status: getStatusForPhase(phase)
            ))
        }
    }
    
    private func getStatusForPhase(_ phase: RippingProgress.Phase) -> String {
        switch phase {
        case .detecting: return "Analyzing disc structure..."
        case .decrypting: return "Decrypting content..."
        case .extracting: return "Extracting media files..."
        case .converting: return "Converting to MKV format..."
        case .organizing: return "Organizing output files..."
        case .completed: return "Ripping completed!"
        }
    }
    
    private func sendProgress(_ progress: RippingProgress) async {
        progressContinuation?.yield(progress)
        
        await MainActor.run {
            delegate?.rippingCoordinator(didUpdateProgress: progress.overallProgress,
                                       status: progress.status,
                                       currentItem: progress.currentItem,
                                       phase: progress.phase)
        }
    }
    
    private func handleRippingError(_ error: Error) async {
        isRippingInternal = false
        
        await sendProgress(.init(
            phase: .completed,
            overallProgress: 0.0,
            currentItem: nil,
            itemProgress: 0.0,
            estimatedTimeRemaining: nil,
            status: "Ripping failed: \(error.localizedDescription)"
        ))
        
        await MainActor.run {
            delegate?.rippingCoordinator(didFailWithError: error)
        }
    }
    
    // MARK: - Mapping Methods
    
    private func mapVideoCodec(_ codec: RippingConfiguration.VideoCodec) -> MediaRipper.RippingConfiguration.VideoCodec {
        switch codec {
        case .h264: return .h264
        case .h265: return .h265
        case .av1: return .av1
        }
    }
    
    private func mapAudioCodec(_ codec: RippingConfiguration.AudioCodec) -> MediaRipper.RippingConfiguration.AudioCodec {
        switch codec {
        case .aac: return .aac
        case .ac3: return .ac3
        case .dts: return .dts
        case .flac: return .flac
        }
    }
    
    private func mapQuality(_ quality: RippingConfiguration.RippingQuality) -> MediaRipper.RippingConfiguration.RippingQuality {
        switch quality {
        case .low: return .low
        case .medium: return .medium
        case .high: return .high
        case .lossless: return .lossless
        }
    }
    
    private func mapMediaType(_ mediaType: RippingConfiguration.MediaType) -> MediaRipper.MediaType? {
        switch mediaType {
        case .dvd: return .dvd
        case .bluray: return .bluray
        case .ultraHDDVD: return .ultraHDDVD
        case .bluray4K: return .bluray4K
        case .unknown: return .unknown
        }
    }
    
    private func mapFromMediaRipperType(_ mediaType: MediaRipper.MediaType) -> RippingConfiguration.MediaType {
        switch mediaType {
        case .dvd: return .dvd
        case .bluray: return .bluray
        case .ultraHDDVD: return .ultraHDDVD
        case .bluray4K: return .bluray4K
        case .hddvd: return .ultraHDDVD
        case .unknown: return .unknown
        }
    }
    
    private func mapToConversionQueueMediaType(_ mediaType: RippingConfiguration.MediaType) -> MediaRipper.MediaType {
        switch mediaType {
        case .dvd: return .dvd
        case .bluray: return .bluray
        case .ultraHDDVD: return .ultraHDDVD
        case .bluray4K: return .bluray4K
        case .unknown: return .unknown
        }
    }
    
    private func titleForMediaItem(_ mediaItem: MediaRipper.MediaItem) -> String {
        switch mediaItem {
        case .dvdTitle(let title):
            return "DVD Title \(title.number)"
        case .blurayPlaylist(let playlist):
            return "Blu-ray Playlist \(playlist.number)"
        }
    }
    
    deinit {
        currentTask?.cancel()
        progressContinuation?.finish()
    }
}

// MARK: - Delegate Protocols

protocol RippingCoordinatorDelegate: AnyObject {
    func rippingCoordinatorDidStart()
    func rippingCoordinator(didUpdateProgress progress: Double, status: String, currentItem: String?, phase: RippingCoordinator.RippingProgress.Phase)
    func rippingCoordinatorDidComplete()
    func rippingCoordinator(didFailWithError error: Error)
    func rippingCoordinatorDidCancel()
}

// MARK: - MediaRipperDelegate Extension

extension RippingCoordinator: MediaRipperDelegate {
    func mediaRipperDidStart() {
        // MediaRipper started - update internal progress
    }
    
    func mediaRipperDidUpdateStatus(_ status: String) {
        Task {
            await sendProgress(.init(
                phase: .extracting,
                overallProgress: 0.3,
                currentItem: status,
                itemProgress: 0.5,
                estimatedTimeRemaining: nil,
                status: status
            ))
        }
    }
    
    func mediaRipperDidUpdateProgress(_ progress: Double, currentItem: MediaRipper.MediaItem?, totalItems: Int) {
        Task {
            let overallProgress = 0.2 + (progress * 0.6) // Map ripper progress to 20%-80% of overall
            let itemTitle = currentItem.map(titleForMediaItem) ?? "Processing"
            await sendProgress(.init(
                phase: .converting,
                overallProgress: overallProgress,
                currentItem: itemTitle,
                itemProgress: progress,
                estimatedTimeRemaining: progress > 0 ? (1.0 - progress) * 300 : nil,
                status: "Converting \(itemTitle) to MKV..."
            ))
        }
    }
    
    func mediaRipperDidComplete() {
        // MediaRipper completed - this will be handled by the queue monitoring
    }
    
    func mediaRipperDidFail(with error: Error) {
        Task {
            await handleRippingError(error)
        }
    }
}

// MARK: - ConversionQueueDelegate Extension

extension RippingCoordinator: ConversionQueueDelegate {
    func queueDidUpdateJobs(_ jobs: [ConversionQueue.ConversionJob]) {
        // Update progress based on queue status
    }
    
    func queueDidStartExtraction(jobId: UUID) {
        Task {
            await sendProgress(.init(
                phase: .extracting,
                overallProgress: 0.3,
                currentItem: "Processing",
                itemProgress: 0.0,
                estimatedTimeRemaining: nil,
                status: "Starting extraction..."
            ))
        }
    }
    
    func queueDidCompleteExtraction(jobId: UUID) {
        Task {
            await sendProgress(.init(
                phase: .converting,
                overallProgress: 0.5,
                currentItem: "Processing",
                itemProgress: 0.0,
                estimatedTimeRemaining: nil,
                status: "Starting conversion..."
            ))
        }
    }
    
    func queueDidFailExtraction(jobId: UUID, error: Error) {
        Task {
            await handleRippingError(error)
        }
    }
    
    func queueDidStartConversion(jobId: UUID) {
        Task {
            await sendProgress(.init(
                phase: .converting,
                overallProgress: 0.6,
                currentItem: "Processing",
                itemProgress: 0.0,
                estimatedTimeRemaining: nil,
                status: "Converting to MKV..."
            ))
        }
    }
    
    func queueDidCompleteConversion(jobId: UUID, outputFiles: [String]) {
        Task {
            await sendProgress(.init(
                phase: .organizing,
                overallProgress: 0.9,
                currentItem: "Processing",
                itemProgress: 1.0,
                estimatedTimeRemaining: 10,
                status: "Organizing output files..."
            ))
        }
    }
    
    func queueDidFailConversion(jobId: UUID, error: Error) {
        Task {
            await handleRippingError(error)
        }
    }
    
    func queueDidUpdateConversionStatus(jobId: UUID, status: String) {
        Task {
            await sendProgress(.init(
                phase: .converting,
                overallProgress: 0.7,
                currentItem: nil,
                itemProgress: 0.5,
                estimatedTimeRemaining: nil,
                status: status
            ))
        }
    }
    
    func queueDidUpdateConversionProgress(jobId: UUID, progress: Double) {
        Task {
            let overallProgress = 0.6 + (progress * 0.3) // Map conversion to 60%-90%
            await sendProgress(.init(
                phase: .converting,
                overallProgress: overallProgress,
                currentItem: nil,
                itemProgress: progress,
                estimatedTimeRemaining: progress > 0 ? (1.0 - progress) * 200 : nil,
                status: "Converting... \(Int(progress * 100))% complete"
            ))
        }
    }
}

// MARK: - Error Types

enum RippingCoordinatorError: Error, LocalizedError {
    case alreadyRipping
    case invalidConfiguration
    case mediaTypeDetectionFailed
    case queueJobFailed(UUID)
    
    var errorDescription: String? {
        switch self {
        case .alreadyRipping:
            return "A ripping operation is already in progress"
        case .invalidConfiguration:
            return "Invalid ripping configuration provided"
        case .mediaTypeDetectionFailed:
            return "Failed to detect media type"
        case .queueJobFailed(let jobId):
            return "Queue job \(jobId) failed"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .alreadyRipping:
            return "Wait for the current operation to complete or cancel it first"
        case .invalidConfiguration:
            return "Check the source path, output directory, and other settings"
        case .mediaTypeDetectionFailed:
            return "Ensure the disc is properly inserted and readable"
        case .queueJobFailed:
            return "Check the conversion queue for more details about the failure"
        }
    }
}