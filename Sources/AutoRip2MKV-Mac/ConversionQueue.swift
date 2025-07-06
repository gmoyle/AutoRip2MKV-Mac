import Foundation
import Cocoa

/// Manages a queue of conversion jobs, separating disc extraction from video conversion
/// This allows for quick disc swapping while maintaining background processing
class ConversionQueue {
    
    // MARK: - Types
    
    enum JobStatus {
        case pending        // Waiting to start
        case extracting     // Reading from disc
        case extracted      // Ready for conversion, disc can be ejected
        case converting     // Converting to MKV
        case completed      // Finished successfully
        case failed(Error)  // Failed with error
        case cancelled      // User cancelled
    }
    
    struct ConversionJob {
        let id: UUID
        let sourcePath: String
        let outputDirectory: String
        let configuration: MediaRipper.RippingConfiguration
        let mediaType: MediaRipper.MediaType
        let discTitle: String
        var status: JobStatus
        var progress: Double
        var extractedDataPath: String?
        var outputFiles: [String]
        var startTime: Date?
        var endTime: Date?
        
        init(sourcePath: String, outputDirectory: String, configuration: MediaRipper.RippingConfiguration, mediaType: MediaRipper.MediaType, discTitle: String) {
            self.id = UUID()
            self.sourcePath = sourcePath
            self.outputDirectory = outputDirectory
            self.configuration = configuration
            self.mediaType = mediaType
            self.discTitle = discTitle
            self.status = .pending
            self.progress = 0.0
            self.outputFiles = []
        }
        
        var formattedDuration: String {
            guard let start = startTime else { return "Not started" }
            let end = endTime ?? Date()
            let duration = end.timeIntervalSince(start)
            let minutes = Int(duration) / 60
            let seconds = Int(duration) % 60
            return String(format: "%d:%02d", minutes, seconds)
        }
        
        var statusDescription: String {
            switch status {
            case .pending: return "Waiting"
            case .extracting: return "Reading disc"
            case .extracted: return "Ready for conversion"
            case .converting: return "Converting"
            case .completed: return "Complete"
            case .failed(let error): return "Failed: \(error.localizedDescription)"
            case .cancelled: return "Cancelled"
            }
        }
    }
    
    // MARK: - Properties
    
    private var jobs: [ConversionJob] = []
    private let jobsQueue = DispatchQueue(label: "com.autoRip2MKV.conversionQueue", attributes: .concurrent)
    private let extractionQueue = DispatchQueue(label: "com.autoRip2MKV.extraction", qos: .userInitiated)
    private let conversionQueue = DispatchQueue(label: "com.autoRip2MKV.conversion", qos: .utility)
    
    private var isExtracting = false
    private var activeConversions = 0
    private let maxConcurrentConversions = 2 // Configurable limit
    
    weak var delegate: ConversionQueueDelegate?
    weak var ejectionDelegate: ConversionQueueEjectionDelegate?
    
    // MARK: - Public Interface
    
    /// Add a new job to the queue
    func addJob(sourcePath: String, outputDirectory: String, configuration: MediaRipper.RippingConfiguration, mediaType: MediaRipper.MediaType, discTitle: String) -> UUID {
        let job = ConversionJob(
            sourcePath: sourcePath,
            outputDirectory: outputDirectory,
            configuration: configuration,
            mediaType: mediaType,
            discTitle: discTitle
        )
        
        jobsQueue.async(flags: .barrier) {
            self.jobs.append(job)
            DispatchQueue.main.async {
                self.delegate?.queueDidUpdateJobs(self.jobs)
            }
        }
        
        processNextJob()
        return job.id
    }
    
    /// Cancel a specific job
    func cancelJob(id: UUID) {
        jobsQueue.async(flags: .barrier) {
            if let index = self.jobs.firstIndex(where: { $0.id == id }) {
                self.jobs[index].status = .cancelled
                DispatchQueue.main.async {
                    self.delegate?.queueDidUpdateJobs(self.jobs)
                }
            }
        }
    }
    
    /// Cancel all pending jobs
    func cancelAllJobs() {
        jobsQueue.async(flags: .barrier) {
            for index in self.jobs.indices {
                if case .pending = self.jobs[index].status {
                    self.jobs[index].status = .cancelled
                }
            }
            DispatchQueue.main.async {
                self.delegate?.queueDidUpdateJobs(self.jobs)
            }
        }
    }
    
    /// Clear completed and failed jobs
    func clearCompletedJobs() {
        jobsQueue.async(flags: .barrier) {
            self.jobs.removeAll { job in
                switch job.status {
                case .completed, .failed, .cancelled:
                    // Clean up any temporary files
                    if let extractedPath = job.extractedDataPath {
                        try? FileManager.default.removeItem(atPath: extractedPath)
                    }
                    return true
                default:
                    return false
                }
            }
            DispatchQueue.main.async {
                self.delegate?.queueDidUpdateJobs(self.jobs)
            }
        }
    }
    
    /// Get current queue status
    func getQueueStatus() -> (total: Int, pending: Int) {
        return jobsQueue.sync {
            let total = jobs.count
            let pending = jobs.filter { if case .pending = $0.status { return true }; return false }.count
            
            return (total, pending)
        }
    }
    
    /// Get detailed queue status
    func getDetailedQueueStatus() -> (
        total: Int, 
        pending: Int, 
        extracting: Int, 
        converting: Int, 
        completed: Int, 
        failed: Int
    ) {
        return jobsQueue.sync {
            let total = jobs.count
            let pending = jobs.filter { 
                if case .pending = $0.status { return true } 
                return false 
            }.count
            let extracting = jobs.filter { 
                if case .extracting = $0.status { return true } 
                return false 
            }.count
            let converting = jobs.filter { 
                if case .converting = $0.status { return true } 
                return false 
            }.count
            let completed = jobs.filter { 
                if case .completed = $0.status { return true } 
                return false 
            }.count
            let failed = jobs.filter { 
                if case .failed = $0.status { return true } 
                return false 
            }.count
            
            return (total, pending, extracting, converting, completed, failed)
        }
    }
    
    /// Get copy of all jobs for UI display
    func getAllJobs() -> [ConversionJob] {
        return jobsQueue.sync { jobs }
    }
    
    // MARK: - Private Implementation
    
    private func processNextJob() {
        jobsQueue.async {
            // Start extraction if not already running and there are pending jobs
            if !self.isExtracting {
                if let nextExtractionJob = self.jobs.first(where: { 
                    if case .pending = $0.status { return true } 
                    return false 
                }) {
                    self.startExtraction(for: nextExtractionJob.id)
                }
            }
            
            // Start conversions if under limit and there are extracted jobs waiting
            if self.activeConversions < self.maxConcurrentConversions {
                let availableSlots = self.maxConcurrentConversions - self.activeConversions
                let extractedJobs = self.jobs.filter { 
                    if case .extracted = $0.status { return true } 
                    return false 
                }
                
                for job in extractedJobs.prefix(availableSlots) {
                    self.startConversion(for: job.id)
                }
            }
        }
    }
    
    private func startExtraction(for jobId: UUID) {
        jobsQueue.async(flags: .barrier) {
            guard let jobIndex = self.jobs.firstIndex(where: { $0.id == jobId }) else { return }
            
            self.jobs[jobIndex].status = .extracting
            self.jobs[jobIndex].startTime = Date()
            self.isExtracting = true
            
            DispatchQueue.main.async {
                self.delegate?.queueDidUpdateJobs(self.jobs)
                self.delegate?.queueDidStartExtraction(jobId: jobId)
            }
        }
        
        extractionQueue.async {
            self.performExtraction(for: jobId)
        }
    }
    
    private func performExtraction(for jobId: UUID) {
        let tempDir = NSTemporaryDirectory().appending("AutoRip2MKV/\(jobId.uuidString)")
        var tempDirCreated = false
        
        // Ensure cleanup happens regardless of success/failure
        defer {
            if tempDirCreated {
                cleanupTempDirectory(tempDir)
            }
        }
        
        do {
            guard let job = getJob(id: jobId) else { return }
            
            // Validate available disk space before extraction
            try validateDiskSpace(for: job, outputDirectory: tempDir)
            
            // Create temporary directory for extracted data
            try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
            tempDirCreated = true
            
            // Perform disc extraction (copy all necessary data from disc)
            try extractDiscData(job: job, toDirectory: tempDir)
            
            // Update job status atomically
            let sourcePath: String? = jobsQueue.sync(flags: .barrier) {
                guard let jobIndex = self.jobs.firstIndex(where: { $0.id == jobId }) else { return nil }
                
                self.jobs[jobIndex].status = .extracted
                self.jobs[jobIndex].extractedDataPath = tempDir
                self.jobs[jobIndex].progress = 1.0
                self.isExtracting = false
                
                let jobSourcePath = self.jobs[jobIndex].sourcePath
                
                DispatchQueue.main.async {
                    self.delegate?.queueDidUpdateJobs(self.jobs)
                    self.delegate?.queueDidCompleteExtraction(jobId: jobId)
                }
                
                return jobSourcePath
            }
            
            // Request ejection outside the barrier to avoid deadlock
            if let sourcePath = sourcePath {
                DispatchQueue.main.async {
                    self.ejectionDelegate?.queueShouldEjectDisc(sourcePath: sourcePath)
                }
            }
            
            // Process next jobs
            processNextJob()
            
        } catch {
            jobsQueue.async(flags: .barrier) {
                if let jobIndex = self.jobs.firstIndex(where: { $0.id == jobId }) {
                    self.jobs[jobIndex].status = .failed(error)
                    self.jobs[jobIndex].endTime = Date()
                }
                self.isExtracting = false
                
                DispatchQueue.main.async {
                    self.delegate?.queueDidUpdateJobs(self.jobs)
                    self.delegate?.queueDidFailExtraction(jobId: jobId, error: error)
                }
            }
            
            processNextJob()
        }
    }
    
    private func startConversion(for jobId: UUID) {
        jobsQueue.async(flags: .barrier) {
            guard let jobIndex = self.jobs.firstIndex(where: { $0.id == jobId }) else { return }
            
            self.jobs[jobIndex].status = .converting
            self.jobs[jobIndex].progress = 0.0
            self.activeConversions += 1
            
            DispatchQueue.main.async {
                self.delegate?.queueDidUpdateJobs(self.jobs)
                self.delegate?.queueDidStartConversion(jobId: jobId)
            }
        }
        
        conversionQueue.async {
            self.performConversion(for: jobId)
        }
    }
    
    private func performConversion(for jobId: UUID) {
        do {
            guard let job = getJob(id: jobId) else { return }
            guard let extractedPath = job.extractedDataPath else {
                throw ConversionQueueError.noExtractedData
            }
            
            // Perform video conversion from extracted data
            let outputFiles = try convertExtractedData(job: job, fromDirectory: extractedPath)
            
            // Update job status
            jobsQueue.async(flags: .barrier) {
                if let jobIndex = self.jobs.firstIndex(where: { $0.id == jobId }) {
                    self.jobs[jobIndex].status = .completed
                    self.jobs[jobIndex].outputFiles = outputFiles
                    self.jobs[jobIndex].endTime = Date()
                    self.jobs[jobIndex].progress = 1.0
                }
                self.activeConversions -= 1
                
                DispatchQueue.main.async {
                    self.delegate?.queueDidUpdateJobs(self.jobs)
                    self.delegate?.queueDidCompleteConversion(jobId: jobId, outputFiles: outputFiles)
                }
            }
            
            // Clean up extracted data
            try? FileManager.default.removeItem(atPath: extractedPath)
            
            // Process next jobs
            processNextJob()
            
        } catch {
            jobsQueue.async(flags: .barrier) {
                if let jobIndex = self.jobs.firstIndex(where: { $0.id == jobId }) {
                    self.jobs[jobIndex].status = .failed(error)
                    self.jobs[jobIndex].endTime = Date()
                }
                self.activeConversions -= 1
                
                DispatchQueue.main.async {
                    self.delegate?.queueDidUpdateJobs(self.jobs)
                    self.delegate?.queueDidFailConversion(jobId: jobId, error: error)
                }
            }
            
            processNextJob()
        }
    }
    
    private func getJob(id: UUID) -> ConversionJob? {
        return jobsQueue.sync {
            jobs.first { $0.id == id }
        }
    }
    
    // Thread-safe job operations with consistent state
    private func withJob<T>(id: UUID, operation: (inout ConversionJob) throws -> T) rethrows -> T? {
        return try jobsQueue.sync(flags: .barrier) {
            guard let index = jobs.firstIndex(where: { $0.id == id }) else { return nil }
            return try operation(&jobs[index])
        }
    }
    
    private func extractDiscData(job: ConversionJob, toDirectory: String) throws {
        // This will copy all necessary data from the disc to local storage
        // Implementation depends on media type
        
        switch job.mediaType {
        case .dvd, .ultraHDDVD:
            try extractDVDData(sourcePath: job.sourcePath, outputPath: toDirectory)
        case .bluray, .bluray4K:
            try extractBluRayData(sourcePath: job.sourcePath, outputPath: toDirectory)
        case .unknown:
            throw ConversionQueueError.unsupportedMediaType
        }
    }
    
    private func extractDVDData(sourcePath: String, outputPath: String) throws {
        // Copy VIDEO_TS folder and all VOB files
        let videoTSSource = sourcePath.appending("/VIDEO_TS")
        let videoTSDestination = outputPath.appending("/VIDEO_TS")
        
        guard FileManager.default.fileExists(atPath: videoTSSource) else {
            throw ConversionQueueError.sourceNotFound
        }
        
        try FileManager.default.copyItem(atPath: videoTSSource, toPath: videoTSDestination)
    }
    
    private func extractBluRayData(sourcePath: String, outputPath: String) throws {
        // Copy BDMV folder structure
        let bdmvSource = sourcePath.appending("/BDMV")
        let bdmvDestination = outputPath.appending("/BDMV")
        
        guard FileManager.default.fileExists(atPath: bdmvSource) else {
            throw ConversionQueueError.sourceNotFound
        }
        
        try FileManager.default.copyItem(atPath: bdmvSource, toPath: bdmvDestination)
    }
    
    private func convertExtractedData(job: ConversionJob, fromDirectory: String) throws -> [String] {
        // Use existing MediaRipper logic but with local extracted data
        let mediaRipper = MediaRipper()
        
        // Use a semaphore for proper async/sync coordination
        let semaphore = DispatchSemaphore(value: 0)
        var conversionResult: Result<[String], Error>?
        
        // Create a custom delegate to capture output files
        let conversionDelegate = ConversionProgressDelegate(
            jobId: job.id,
            queueDelegate: self.delegate
        ) { result in
            conversionResult = result
            semaphore.signal()
        }
        mediaRipper.delegate = conversionDelegate
        
        // Start conversion from extracted data
        mediaRipper.startRipping(mediaPath: fromDirectory, configuration: job.configuration)
        
        // Wait for completion with timeout (30 minutes max)
        let timeoutResult = semaphore.wait(timeout: .now() + 1800) // 30 minutes
        
        if timeoutResult == .timedOut {
            mediaRipper.cancelRipping()
            throw ConversionQueueError.conversionTimeout
        }
        
        guard let result = conversionResult else {
            throw ConversionQueueError.conversionFailed
        }
        
        switch result {
        case .success(let outputFiles):
            return outputFiles
        case .failure(let error):
            throw error
        }
    }
    
    // MARK: - Helper Methods
    
    private func validateDiskSpace(for job: ConversionJob, outputDirectory: String) throws {
        let fileManager = FileManager.default
        
        // Get available space
        guard let attributes = try? fileManager.attributesOfFileSystem(forPath: outputDirectory),
              let freeBytes = attributes[.systemFreeSize] as? Int64 else {
            throw ConversionQueueError.diskSpaceCheckFailed
        }
        
        // Estimate required space based on media type (conservative estimates)
        let requiredBytes: Int64
        switch job.mediaType {
        case .dvd, .ultraHDDVD:
            requiredBytes = 10_000_000_000 // 10GB for DVD
        case .bluray:
            requiredBytes = 50_000_000_000 // 50GB for Blu-ray
        case .bluray4K:
            requiredBytes = 100_000_000_000 // 100GB for 4K Blu-ray
        case .unknown:
            requiredBytes = 50_000_000_000 // Default to safe amount
        }
        
        if freeBytes < requiredBytes {
            throw ConversionQueueError.insufficientDiskSpace(required: requiredBytes, available: freeBytes)
        }
    }
    
    private func cleanupTempDirectory(_ path: String) {
        do {
            if FileManager.default.fileExists(atPath: path) {
                try FileManager.default.removeItem(atPath: path)
            }
        } catch {
            // Log error but don't fail - this is cleanup
            print("Warning: Failed to cleanup temp directory \(path): \(error)")
        }
    }
}

// MARK: - Helper Classes

private class ConversionProgressDelegate: MediaRipperDelegate {
    let jobId: UUID
    weak var queueDelegate: ConversionQueueDelegate?
    var outputFiles: [String] = []
    private let completion: (Result<[String], Error>) -> Void
    
    init(jobId: UUID, queueDelegate: ConversionQueueDelegate?, completion: @escaping (Result<[String], Error>) -> Void) {
        self.jobId = jobId
        self.queueDelegate = queueDelegate
        self.completion = completion
    }
    
    func ripperDidStart() {
        DispatchQueue.main.async {
            self.queueDelegate?.queueDidUpdateConversionStatus(jobId: self.jobId, status: "Starting conversion...")
        }
    }
    
    func ripperDidUpdateStatus(_ status: String) {
        DispatchQueue.main.async {
            self.queueDelegate?.queueDidUpdateConversionStatus(jobId: self.jobId, status: status)
        }
    }
    
    func ripperDidUpdateProgress(_ progress: Double, currentItem: MediaRipper.MediaItem?, totalItems: Int) {
        DispatchQueue.main.async {
            self.queueDelegate?.queueDidUpdateConversionProgress(jobId: self.jobId, progress: progress)
        }
    }
    
    func ripperDidComplete() {
        completion(.success(outputFiles))
    }
    
    func ripperDidFail(with error: Error) {
        completion(.failure(error))
    }
}

// MARK: - Delegate Protocol

protocol ConversionQueueDelegate: AnyObject {
    func queueDidUpdateJobs(_ jobs: [ConversionQueue.ConversionJob])
    func queueDidStartExtraction(jobId: UUID)
    func queueDidCompleteExtraction(jobId: UUID)
    func queueDidFailExtraction(jobId: UUID, error: Error)
    func queueDidStartConversion(jobId: UUID)
    func queueDidCompleteConversion(jobId: UUID, outputFiles: [String])
    func queueDidFailConversion(jobId: UUID, error: Error)
    func queueDidUpdateConversionStatus(jobId: UUID, status: String)
    func queueDidUpdateConversionProgress(jobId: UUID, progress: Double)
}

protocol ConversionQueueEjectionDelegate: AnyObject {
    func queueShouldEjectDisc(sourcePath: String)
}

// MARK: - Error Types

enum ConversionQueueError: Error {
    case unsupportedMediaType
    case sourceNotFound
    case noExtractedData
    case conversionFailed
    case conversionTimeout
    case diskSpaceCheckFailed
    case insufficientDiskSpace(required: Int64, available: Int64)
    
    var localizedDescription: String {
        switch self {
        case .unsupportedMediaType:
            return "Unsupported media type"
        case .sourceNotFound:
            return "Source media not found"
        case .noExtractedData:
            return "No extracted data available"
        case .conversionFailed:
            return "Conversion failed"
        case .conversionTimeout:
            return "Conversion timed out after 30 minutes"
        case .diskSpaceCheckFailed:
            return "Failed to check available disk space"
        case .insufficientDiskSpace(let required, let available):
            let requiredGB = ByteCountFormatter.string(fromByteCount: required, countStyle: .file)
            let availableGB = ByteCountFormatter.string(fromByteCount: available, countStyle: .file)
            return "Insufficient disk space. Required: \(requiredGB), Available: \(availableGB)"
        }
    }
}
