import Foundation
import Cocoa

/// Manages a queue of conversion jobs, separating disc extraction from video conversion
/// This allows for quick disc swapping while maintaining background processing
class ConversionQueue {
    
    /// Priority levels for job processing
    enum JobPriority: Int, Comparable {
        case low = 0
        case normal = 1
        case high = 2
        case urgent = 3
        
        static func < (lhs: JobPriority, rhs: JobPriority) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }
        
        var description: String {
            switch self {
            case .low: return "Low"
            case .normal: return "Normal"
            case .high: return "High"
            case .urgent: return "Urgent"
            }
        }
    }
    
    enum JobStatus: Equatable {
        case pending        // Waiting to start
        case extracting     // Reading from disc
        case extracted      // Ready for conversion, disc can be ejected
        case converting     // Converting to MKV
        case completed      // Finished successfully
        case failed(Error)  // Failed with error
        case cancelled      // User cancelled

        static func == (lhs: JobStatus, rhs: JobStatus) -> Bool {
            switch (lhs, rhs) {
            case (.pending, .pending),
                 (.extracting, .extracting),
                 (.extracted, .extracted),
                 (.converting, .converting),
                 (.completed, .completed),
                 (.cancelled, .cancelled):
                return true
            case (.failed, .failed):
                return true  // For testing purposes, consider all failures equal
            default:
                return false
            }
        }
    }

    struct ConversionJob {
        let id: UUID
        let sourcePath: String
        let outputDirectory: String
        let configuration: MediaRipper.RippingConfiguration
        let mediaType: MediaRipper.MediaType
        let discTitle: String
        var priority: JobPriority
        var status: JobStatus
        var progress: Double
        var extractedDataPath: String?
        var outputFiles: [String]
        var startTime: Date?
        var endTime: Date?
        var estimatedDuration: TimeInterval?  // Predicted duration based on media type
        var addedTime: Date                   // When job was added to queue

        init(sourcePath: String, outputDirectory: String, configuration: MediaRipper.RippingConfiguration, mediaType: MediaRipper.MediaType, discTitle: String, priority: JobPriority = .normal) {
            self.id = UUID()
            self.sourcePath = sourcePath
            self.outputDirectory = outputDirectory
            self.configuration = configuration
            self.mediaType = mediaType
            self.discTitle = discTitle
            self.priority = priority
            self.status = .pending
            self.progress = 0.0
            self.outputFiles = []
            self.addedTime = Date()
            
            // Estimate duration based on media type and codec
            self.estimatedDuration = Self.estimateJobDuration(mediaType: mediaType, codec: configuration.videoCodec)
        }
        
        /// Estimate job duration based on media type and codec complexity
        private static func estimateJobDuration(mediaType: MediaRipper.MediaType, codec: MediaRipper.RippingConfiguration.VideoCodec) -> TimeInterval {
            // Base duration estimates (in seconds)
            let baseDuration: TimeInterval
            switch mediaType {
            case .dvd, .ultraHDDVD:
                baseDuration = 1800  // ~30 minutes for DVD
            case .hddvd:
                baseDuration = 2400  // ~40 minutes for HD DVD
            case .bluray:
                baseDuration = 3600  // ~60 minutes for Blu-ray
            case .bluray4K:
                baseDuration = 5400  // ~90 minutes for 4K Blu-ray
            case .unknown:
                baseDuration = 2400  // Default estimate
            }
            
            // Codec multiplier
            let codecMultiplier: Double
            switch codec {
            case .h264:
                codecMultiplier = 1.0   // Baseline
            case .h265:
                codecMultiplier = 1.5   // 50% slower
            case .vp9:
                codecMultiplier = 2.0   // 2x slower
            case .av1:
                codecMultiplier = 3.0   // 3x slower
            }
            
            return baseDuration * codecMultiplier
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
    private(set) var maxConcurrentConversions = 2 // Configurable limit

    weak var delegate: ConversionQueueDelegate?
    weak var ejectionDelegate: ConversionQueueEjectionDelegate?

    // Testing mode - when true, jobs are not automatically processed
    private let testMode: Bool

    // MARK: - Initialization

    init(testMode: Bool = false) {
        self.testMode = testMode
        Logger.shared.logQueue("ConversionQueue initialized", level: .info)
    }

    // MARK: - Time Estimation

    /// Estimate time remaining for a job based on progress and predicted duration
    func estimateTimeRemaining(for job: ConversionJob) -> TimeInterval? {
        // If job has a start time and progress, calculate based on actual rate
        if let startTime = job.startTime, job.progress > 0.05 {
            let elapsed = Date().timeIntervalSince(startTime)
            let estimatedTotal = elapsed / job.progress
            let remaining = estimatedTotal * (1.0 - job.progress)
            return max(0, remaining)
        }
        
        // Otherwise, use the predicted duration
        if let predicted = job.estimatedDuration {
            return predicted * (1.0 - job.progress)
        }
        
        // Fallback to historical average if available
        let completedJobs = jobsQueue.sync {
            jobs.filter { if case .completed = $0.status { return true }; return false }
        }
        guard !completedJobs.isEmpty else { return nil }
        
        var totalDuration: TimeInterval = 0
        var matchingJobs = 0
        for completedJob in completedJobs {
            // Prefer jobs with matching media type and codec
            if completedJob.mediaType == job.mediaType && 
               completedJob.configuration.videoCodec == job.configuration.videoCodec,
               let start = completedJob.startTime, 
               let end = completedJob.endTime {
                totalDuration += end.timeIntervalSince(start)
                matchingJobs += 1
            }
        }
        
        if matchingJobs > 0 {
            let avgDuration = totalDuration / Double(matchingJobs)
            return avgDuration * (1.0 - job.progress)
        }
        
        // Fall back to any completed jobs if no matching ones
        totalDuration = 0
        for completedJob in completedJobs {
            if let start = completedJob.startTime, let end = completedJob.endTime {
                totalDuration += end.timeIntervalSince(start)
            }
        }
        let avgDuration = totalDuration / Double(completedJobs.count)
        return avgDuration * (1.0 - job.progress)
    }

    /// Estimate time remaining for the entire queue with priority awareness
    func estimateQueueTimeRemaining() -> TimeInterval? {
        return jobsQueue.sync {
            var totalRemaining: TimeInterval = 0
            
            // Get active jobs and calculate their remaining time
            let activeJobs = jobs.filter { 
                $0.status == .extracting || $0.status == .converting 
            }
            for job in activeJobs {
                if let remaining = estimateTimeRemaining(for: job) {
                    totalRemaining += remaining
                }
            }
            
            // Get pending and extracted jobs, accounting for priority
            let waitingJobs = jobs.filter {
                $0.status == .pending || $0.status == .extracted
            }.sorted { job1, job2 in
                if job1.priority != job2.priority {
                    return job1.priority > job2.priority
                }
                return job1.addedTime < job2.addedTime
            }
            
            // Estimate based on predicted durations and concurrency
            for (index, job) in waitingJobs.enumerated() {
                let duration = job.estimatedDuration ?? 3600 // Default 1 hour
                // Account for parallel processing
                let queuePosition = index / maxConcurrentConversions
                let parallelDelay = Double(queuePosition) * duration
                totalRemaining += duration + parallelDelay
            }
            
            return totalRemaining > 0 ? totalRemaining : nil
        }
    }

    // MARK: - Public Interface

    /// Add a new job to the queue
    func addJob(sourcePath: String, outputDirectory: String, configuration: MediaRipper.RippingConfiguration, mediaType: MediaRipper.MediaType, discTitle: String, priority: JobPriority = .normal) -> UUID {
        let job = ConversionJob(
            sourcePath: sourcePath,
            outputDirectory: outputDirectory,
            configuration: configuration,
            mediaType: mediaType,
            discTitle: discTitle,
            priority: priority
        )

        jobsQueue.async(flags: .barrier) {
            self.jobs.append(job)
            Logger.shared.logQueue("Added new job \(job.id) for disc title: \(job.discTitle) with priority: \(job.priority.description)", level: .info)
            DispatchQueue.main.async {
                self.delegate?.queueDidUpdateJobs(self.jobs)
            }
        }

        if !testMode {
            processNextJob()
        }
        return job.id
    }

    /// Cancel a specific job
    func cancelJob(id: UUID) {
        jobsQueue.async(flags: .barrier) {
            if let index = self.jobs.firstIndex(where: { $0.id == id }) {
                self.jobs[index].status = .cancelled
                Logger.shared.logQueue("Cancelled job \(id)", level: .info)
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
    
    /// Configure maximum concurrent conversions
    /// - Parameter maxConcurrent: Number of simultaneous conversions (1-4 recommended)
    func setMaxConcurrentConversions(_ maxConcurrent: Int) {
        let validatedMax = max(1, min(maxConcurrent, 8)) // Clamp between 1-8
        jobsQueue.sync(flags: .barrier) {
            self.maxConcurrentConversions = validatedMax
            Logger.shared.logQueue("Updated max concurrent conversions to \(validatedMax)", level: .info)
        }
        // Trigger processing in case more slots opened up
        if !testMode {
            processNextJob()
        }
    }
    
    /// Update priority of a pending job
    /// - Parameters:
    ///   - jobId: UUID of the job to update
    ///   - priority: New priority level
    func updateJobPriority(jobId: UUID, priority: JobPriority) {
        jobsQueue.async(flags: .barrier) {
            guard let index = self.jobs.firstIndex(where: { $0.id == jobId }) else { return }
            
            // Only allow priority changes for pending jobs
            if case .pending = self.jobs[index].status {
                let oldPriority = self.jobs[index].priority
                self.jobs[index].priority = priority
                Logger.shared.logQueue("Updated job \(jobId) priority from \(oldPriority.description) to \(priority.description)", level: .info)
                
                DispatchQueue.main.async {
                    self.delegate?.queueDidUpdateJobs(self.jobs)
                }
            }
        }
        
        // Re-process queue in case priority change affects order
        if !testMode {
            processNextJob()
        }
    }

    /// Queue status information
    struct QueueStatus {
        let total: Int
        let pending: Int
        let extracting: Int
        let converting: Int
        let completed: Int
        let failed: Int
    }

    /// Get current queue status
    func getQueueStatus() -> QueueStatus {
        return jobsQueue.sync {
            let total = jobs.count
            let pending = jobs.filter { if case .pending = $0.status { return true }; return false }.count
            let extracting = jobs.filter { if case .extracting = $0.status { return true }; return false }.count
            let converting = jobs.filter { if case .converting = $0.status { return true }; return false }.count
            let completed = jobs.filter { if case .completed = $0.status { return true }; return false }.count
            let failed = jobs.filter { if case .failed = $0.status { return true }; return false }.count
            return QueueStatus(
                total: total,
                pending: pending,
                extracting: extracting,
                converting: converting,
                completed: completed,
                failed: failed
            )
        }
    }

    /// Get extracting job count
    func getExtractingCount() -> Int {
        return jobsQueue.sync {
            jobs.filter { if case .extracting = $0.status { return true }; return false }.count
        }
    }

    /// Get converting job count
    func getConvertingCount() -> Int {
        return jobsQueue.sync {
            jobs.filter { if case .converting = $0.status { return true }; return false }.count
        }
    }

    /// Get completed job count
    func getCompletedCount() -> Int {
        return jobsQueue.sync {
            jobs.filter { if case .completed = $0.status { return true }; return false }.count
        }
    }

    /// Get failed job count
    func getFailedCount() -> Int {
        return jobsQueue.sync {
            jobs.filter { if case .failed = $0.status { return true }; return false }.count
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
                // Get all pending jobs and sort by priority (highest first), then by addedTime (oldest first)
                let pendingJobs = self.jobs.filter {
                    if case .pending = $0.status { return true }
                    return false
                }.sorted { job1, job2 in
                    // First sort by priority (higher priority first)
                    if job1.priority != job2.priority {
                        return job1.priority > job2.priority
                    }
                    // If same priority, sort by addedTime (older first - FIFO within priority)
                    return job1.addedTime < job2.addedTime
                }
                
                if let nextExtractionJob = pendingJobs.first {
                    self.startExtraction(for: nextExtractionJob.id)
                }
            }

            // Start conversions if under limit and there are extracted jobs waiting
            if self.activeConversions < self.maxConcurrentConversions {
                let availableSlots = self.maxConcurrentConversions - self.activeConversions
                
                // Sort extracted jobs by priority as well
                let extractedJobs = self.jobs.filter {
                    if case .extracted = $0.status { return true }
                    return false
                }.sorted { job1, job2 in
                    if job1.priority != job2.priority {
                        return job1.priority > job2.priority
                    }
                    return job1.addedTime < job2.addedTime
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
            
            Logger.shared.logQueue("Starting extraction for job \(jobId)", level: .info)
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

            ScriptRunner.shared.runHook(.preProcessing, job: job)

            // Validate available disk space before extraction
            try validateDiskSpace(for: job, outputDirectory: tempDir)

            // Create temporary directory for extracted data
            try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
            tempDirCreated = true

            // Perform disc extraction (copy all necessary data from disc)
            try extractDiscData(job: job, toDirectory: tempDir)

            // Update job status atomically
            let sourcePath: String? = jobsQueue.sync(flags: .barrier) {
                guard let jobIndex = self.jobs.firstIndex(where: { $0.id == jobId }) else { return "" }

                self.jobs[jobIndex].status = .extracted
                self.jobs[jobIndex].extractedDataPath = tempDir
                self.jobs[jobIndex].progress = 1.0
                self.isExtracting = false

                let jobSourcePath = self.jobs[jobIndex].sourcePath
                Logger.shared.logQueue("Extraction completed for job \(jobId)", level: .info)

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

                Logger.shared.logError(error, context: "Extraction failed for job \(jobId)")
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

            Logger.shared.logQueue("Starting conversion for job \(jobId)", level: .info)
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
            let resolvedOutputFiles = resolveOutputFiles(for: job, convertedFiles: outputFiles)

            var scriptJob = job
            scriptJob.endTime = Date()
            scriptJob.outputFiles = resolvedOutputFiles

            // Update job status
            jobsQueue.async(flags: .barrier) {
                if let jobIndex = self.jobs.firstIndex(where: { $0.id == jobId }) {
                    self.jobs[jobIndex].status = .completed
                    self.jobs[jobIndex].outputFiles = resolvedOutputFiles
                    self.jobs[jobIndex].endTime = scriptJob.endTime
                    self.jobs[jobIndex].progress = 1.0
                    Logger.shared.logQueue("Conversion completed for job \(jobId) with \(resolvedOutputFiles.count) output files", level: .info)
                }
                self.activeConversions -= 1

                DispatchQueue.main.async {
                    self.delegate?.queueDidUpdateJobs(self.jobs)
                    self.delegate?.queueDidCompleteConversion(jobId: jobId, outputFiles: resolvedOutputFiles)
                }
            }

            ScriptRunner.shared.runHook(.postProcessing, job: scriptJob, outputFiles: resolvedOutputFiles)

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

                Logger.shared.logError(error, context: "Conversion failed for job \(jobId)")
                DispatchQueue.main.async {
                    self.delegate?.queueDidUpdateJobs(self.jobs)
                    self.delegate?.queueDidFailConversion(jobId: jobId, error: error)
                }
            }

            if let job = getJob(id: jobId) {
                var scriptJob = job
                scriptJob.endTime = Date()
                ScriptRunner.shared.runHook(.postProcessing, job: scriptJob, outputFiles: job.outputFiles, error: error)
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
        case .dvd, .ultraHDDVD, .hddvd:
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
            // Check if the source path itself exists to provide better error message
            if !FileManager.default.fileExists(atPath: sourcePath) {
                throw ConversionQueueError.sourceDiscEjected(sourcePath)
            } else {
                throw ConversionQueueError.sourceNotFound
            }
        }

        try FileManager.default.copyItem(atPath: videoTSSource, toPath: videoTSDestination)
    }

    private func extractBluRayData(sourcePath: String, outputPath: String) throws {
        // Copy BDMV folder structure
        let bdmvSource = sourcePath.appending("/BDMV")
        let bdmvDestination = outputPath.appending("/BDMV")

        guard FileManager.default.fileExists(atPath: bdmvSource) else {
            // Check if the source path itself exists to provide better error message
            if !FileManager.default.fileExists(atPath: sourcePath) {
                throw ConversionQueueError.sourceDiscEjected(sourcePath)
            } else {
                throw ConversionQueueError.sourceNotFound
            }
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

        // Check space on the parent directory since outputDirectory may not exist yet
        let parentDirectory = (outputDirectory as NSString).deletingLastPathComponent
        let directoryToCheck = fileManager.fileExists(atPath: outputDirectory) ? outputDirectory : parentDirectory

        // Get available space
        guard let attributes = try? fileManager.attributesOfFileSystem(forPath: directoryToCheck),
              let freeBytes = attributes[.systemFreeSize] as? Int64 else {
            throw ConversionQueueError.diskSpaceCheckFailed
        }

        // Estimate required space based on media type (conservative estimates)
        let requiredBytes: Int64
        switch job.mediaType {
        case .dvd, .ultraHDDVD, .hddvd:
            requiredBytes = 15_000_000_000 // 15GB for HD DVD (more than DVD)
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
            Logger.shared.logError(error, context: "Failed to cleanup temp directory \(path)", category: .filesystem)
        }
    }

    private func resolveOutputFiles(for job: ConversionJob, convertedFiles: [String]) -> [String] {
        if !convertedFiles.isEmpty {
            return convertedFiles
        }

        let outputDirectory = job.outputDirectory
        guard FileManager.default.fileExists(atPath: outputDirectory) else { return [] }

        let startTime = job.startTime ?? Date.distantPast
        var results: [String] = []

        if let enumerator = FileManager.default.enumerator(atPath: outputDirectory) {
            for case let file as String in enumerator {
                let fileURL = URL(fileURLWithPath: outputDirectory).appendingPathComponent(file)
                guard fileURL.pathExtension.lowercased() == "mkv" else { continue }

                if let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
                   let modified = attributes[.modificationDate] as? Date,
                   modified < startTime {
                    continue
                }

                results.append(fileURL.path)
            }
        }

        return results.sorted()
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

    func mediaRipperDidStart() {
        DispatchQueue.main.async {
            self.queueDelegate?.queueDidUpdateConversionStatus(jobId: self.jobId, status: "Starting conversion...")
        }
    }

    func mediaRipperDidUpdateStatus(_ status: String) {
        DispatchQueue.main.async {
            self.queueDelegate?.queueDidUpdateConversionStatus(jobId: self.jobId, status: status)
        }
    }

    func mediaRipperDidUpdateProgress(_ progress: Double, currentItem: MediaRipper.MediaItem?, totalItems: Int) {
        DispatchQueue.main.async {
            self.queueDelegate?.queueDidUpdateConversionProgress(jobId: self.jobId, progress: progress)
        }
    }

    func mediaRipperDidComplete() {
        completion(.success(outputFiles))
    }

    func mediaRipperDidFail(with error: Error) {
        completion(.failure(error))
    }
}


// MARK: - Error Types

enum ConversionQueueError: Error {
    case unsupportedMediaType
    case sourceNotFound
    case sourceDiscEjected(String)
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
        case .sourceDiscEjected(let path):
            return "Source disc at '\(path)' was ejected before extraction could complete"
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
