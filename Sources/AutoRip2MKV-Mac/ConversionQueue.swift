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

    private var isProcessing = false  // true while any job is ripping or encoding
    private var activeRipper: MediaRipper?  // ripper for the currently-extracting job, if any

    weak var delegate: ConversionQueueDelegate?
    /// Secondary observer (main window) — receives the same callbacks as `delegate`,
    /// which the queue window claims when open.
    weak var mainDelegate: ConversionQueueDelegate?
    weak var ejectionDelegate: ConversionQueueEjectionDelegate?

    /// Dispatches a callback to both delegates (skipping a duplicate reference).
    fileprivate func notifyDelegates(_ body: (ConversionQueueDelegate) -> Void) {
        if let d = delegate { body(d) }
        if let d = mainDelegate, d !== delegate { body(d) }
    }

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
            
            // Jobs run serially — each waits for all previous to finish
            for job in waitingJobs {
                let duration = job.estimatedDuration ?? 3600
                totalRemaining += duration
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
                self.notifyDelegates { $0.queueDidUpdateJobs(self.jobs) }
            }
        }

        if !testMode {
            processNextJob()
        }
        return job.id
    }

    /// Add a job that has already been extracted (VOB on disk), skipping straight to conversion.
    /// The queue takes ownership of the VOB file and deletes it after conversion.
    func addPreExtractedVOBJob(vocPath: String, outputPath: String, discTitle: String,
                               mediaType: MediaRipper.MediaType,
                               configuration: MediaRipper.RippingConfiguration) {
        var job = ConversionJob(
            sourcePath: vocPath,
            outputDirectory: (outputPath as NSString).deletingLastPathComponent,
            configuration: configuration,
            mediaType: mediaType,
            discTitle: discTitle
        )
        job.status = .extracted
        job.extractedDataPath = vocPath
        // Store the intended output file in outputFiles so conversion knows where to write
        job.outputFiles = [outputPath]

        jobsQueue.async(flags: .barrier) {
            self.jobs.append(job)
            Logger.shared.logQueue("Added pre-extracted VOB job \(job.id) for: \(discTitle)", level: .info)
            DispatchQueue.main.async {
                self.notifyDelegates { $0.queueDidUpdateJobs(self.jobs) }
            }
        }

        if !testMode {
            processNextJob()
        }
    }

    /// Cancel a specific job. If the job is currently extracting, the active ripper
    /// is cancelled as well (which terminates its ffmpeg pipeline).
    func cancelJob(id: UUID) {
        jobsQueue.async(flags: .barrier) {
            if let index = self.jobs.firstIndex(where: { $0.id == id }) {
                if case .extracting = self.jobs[index].status {
                    self.activeRipper?.cancelRipping()
                }
                self.jobs[index].status = .cancelled
                Logger.shared.logQueue("Cancelled job \(id)", level: .info)
                DispatchQueue.main.async {
                    self.notifyDelegates { $0.queueDidUpdateJobs(self.jobs) }
                }
            }
        }
    }

    /// Serializable fingerprint of the settings that affect rip output, stored in
    /// the completion marker so a settings change triggers an automatic re-rip.
    static func settingsFingerprint(of cfg: MediaRipper.RippingConfiguration) -> [String: String] {
        return [
            "videoCodec": String(describing: cfg.videoCodec),
            "audioCodec": String(describing: cfg.audioCodec),
            "quality": String(describing: cfg.quality),
            "autoDeinterlace": String(cfg.autoDeinterlace),
            "includeSubtitles": String(cfg.includeSubtitles),
            "includeChapters": String(cfg.includeChapters)
        ]
    }

    /// Write rip_complete.json next to the output files. Its presence (plus a
    /// matching settings fingerprint) lets auto-rip skip discs already ripped.
    private func writeRipCompleteMarker(job: ConversionJob, outputFiles: [String]) {
        guard let firstOutput = outputFiles.first else { return }
        let dir = (firstOutput as NSString).deletingLastPathComponent
        let marker: [String: Any] = [
            "disc_title": job.discTitle,
            "volume_name": (job.sourcePath as NSString).lastPathComponent,
            "completed": ISO8601DateFormatter().string(from: Date()),
            "output_files": outputFiles.map { ($0 as NSString).lastPathComponent },
            "settings": Self.settingsFingerprint(of: job.configuration)
        ]
        if let data = try? JSONSerialization.data(withJSONObject: marker, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: URL(fileURLWithPath: dir).appendingPathComponent("rip_complete.json"))
        }
    }

    /// Record progress for a job and refresh observers. Small deltas are dropped
    /// to keep table reloads infrequent.
    func setJobProgress(id: UUID, progress: Double) {
        jobsQueue.async(flags: .barrier) {
            guard let idx = self.jobs.firstIndex(where: { $0.id == id }) else { return }
            let delta = abs(self.jobs[idx].progress - progress)
            guard delta >= 0.005 || progress >= 1.0 else { return }
            self.jobs[idx].progress = progress
            DispatchQueue.main.async {
                self.notifyDelegates { $0.queueDidUpdateJobs(self.jobs) }
            }
        }
    }

    /// Remove a single inactive job (pending, completed, failed, or cancelled) from the list.
    func removeJob(id: UUID) {
        jobsQueue.async(flags: .barrier) {
            guard let index = self.jobs.firstIndex(where: { $0.id == id }) else { return }
            switch self.jobs[index].status {
            case .extracting, .extracted, .converting:
                return  // never remove an active job
            default:
                self.jobs.remove(at: index)
                Logger.shared.logQueue("Removed job \(id)", level: .info)
                DispatchQueue.main.async {
                    self.notifyDelegates { $0.queueDidUpdateJobs(self.jobs) }
                }
            }
        }
    }

    /// Reset a failed or cancelled job to pending and reprocess the queue.
    func retryJob(id: UUID) {
        jobsQueue.async(flags: .barrier) {
            guard let index = self.jobs.firstIndex(where: { $0.id == id }) else { return }
            switch self.jobs[index].status {
            case .failed, .cancelled:
                self.jobs[index].status = .pending
                self.jobs[index].progress = 0.0
                self.jobs[index].startTime = nil
                self.jobs[index].endTime = nil
                self.jobs[index].outputFiles = []
                Logger.shared.logQueue("Retrying job \(id)", level: .info)
                DispatchQueue.main.async {
                    self.notifyDelegates { $0.queueDidUpdateJobs(self.jobs) }
                }
            default:
                return
            }
        }
        if !testMode {
            processNextJob()
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
                self.notifyDelegates { $0.queueDidUpdateJobs(self.jobs) }
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
                self.notifyDelegates { $0.queueDidUpdateJobs(self.jobs) }
            }
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
                    self.notifyDelegates { $0.queueDidUpdateJobs(self.jobs) }
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

    /// Returns true if an active or pending job already exists for this source path.
    func hasActiveJob(forSourcePath path: String) -> Bool {
        return jobsQueue.sync {
            jobs.contains { job in
                job.sourcePath == path &&
                job.status != .completed &&
                job.status != .cancelled &&
                !{ if case .failed = job.status { return true }; return false }()
            }
        }
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
            guard !self.isProcessing else { return }

            // Pick the highest-priority pending job (FIFO within priority)
            let next = self.jobs.filter {
                if case .pending = $0.status { return true }
                return false
            }.sorted { a, b in
                a.priority != b.priority ? a.priority > b.priority : a.addedTime < b.addedTime
            }.first

            if let job = next {
                self.startRipping(for: job.id)
            }
        }
    }

    private func startRipping(for jobId: UUID) {
        jobsQueue.async(flags: .barrier) {
            guard let idx = self.jobs.firstIndex(where: { $0.id == jobId }) else { return }
            self.jobs[idx].status = .extracting
            self.jobs[idx].startTime = Date()
            self.isProcessing = true
            Logger.shared.logQueue("Starting rip for job \(jobId)", level: .info)
            DispatchQueue.main.async {
                self.notifyDelegates { $0.queueDidUpdateJobs(self.jobs) }
                self.notifyDelegates { $0.queueDidStartExtraction(jobId: jobId) }
            }
        }
        extractionQueue.async { self.performRip(for: jobId) }
    }

    /// Drives a full MediaRipper session for one disc job.
    /// Phase 1 (.extracting): sectors fed into ffmpeg pipes; ends when disc can be ejected.
    /// Phase 2 (.extracted → .converting): waits on background ffmpeg processes serially.
    private func performRip(for jobId: UUID) {
        guard let job = getJob(id: jobId) else { return }

        ScriptRunner.shared.runHook(.preProcessing, job: job)

        let ripper = MediaRipper()
        jobsQueue.async(flags: .barrier) { self.activeRipper = ripper }
        let semaphore = DispatchSemaphore(value: 0)
        var ripError: Error?

        // Delegate bridges MediaRipper callbacks into queue state transitions
        let bridge = QueueRipperDelegate(
            jobId: jobId,
            queue: self,
            onComplete: { semaphore.signal() },
            onFail: { error in ripError = error; semaphore.signal() }
        )
        ripper.delegate = bridge

        ripper.startRipping(mediaPath: job.sourcePath, configuration: job.configuration)

        // Wait for mediaRipperDidComplete (all sectors fed, disc can eject)
        semaphore.wait()

        if let error = ripError {
            jobsQueue.async(flags: .barrier) {
                if let idx = self.jobs.firstIndex(where: { $0.id == jobId }) {
                    self.jobs[idx].status = .failed(error)
                    self.jobs[idx].endTime = Date()
                }
                self.isProcessing = false
                self.activeRipper = nil
                Logger.shared.logError(error, context: "Rip failed for job \(jobId)")
                DispatchQueue.main.async {
                    self.notifyDelegates { $0.queueDidUpdateJobs(self.jobs) }
                    self.notifyDelegates { $0.queueDidFailExtraction(jobId: jobId, error: error) }
                }
            }
            processNextJob()
            return
        }

        // Disc is done — transition to .extracted and request eject
        let sourcePath = job.sourcePath
        jobsQueue.async(flags: .barrier) {
            if let idx = self.jobs.firstIndex(where: { $0.id == jobId }) {
                self.jobs[idx].status = .extracted
                Logger.shared.logQueue("Disc read complete for job \(jobId), ejecting", level: .info)
                DispatchQueue.main.async {
                    self.notifyDelegates { $0.queueDidUpdateJobs(self.jobs) }
                    self.notifyDelegates { $0.queueDidCompleteExtraction(jobId: jobId) }
                    self.ejectionDelegate?.queueShouldEjectDisc(sourcePath: sourcePath)
                }
            }
        }

        // Phase 2: wait for each background ffmpeg process serially
        jobsQueue.async(flags: .barrier) {
            if let idx = self.jobs.firstIndex(where: { $0.id == jobId }) {
                self.jobs[idx].status = .converting
                DispatchQueue.main.async {
                    self.notifyDelegates { $0.queueDidUpdateJobs(self.jobs) }
                    self.notifyDelegates { $0.queueDidStartConversion(jobId: jobId) }
                }
            }
        }

        var outputFiles: [String] = []
        var encodeError: Error?

        for entry in ripper.backgroundEncodingProcesses {
            entry.process.waitUntilExit()
            if entry.process.terminationStatus == 0 {
                outputFiles.append(entry.outputPath)
                ripper.delegate?.mediaRipperDidUpdateStatus("Encoding complete: \(entry.outputPath)")
            } else {
                encodeError = MediaRipperError.conversionFailed
                ripper.delegate?.mediaRipperDidUpdateStatus("Encoding failed for title \(entry.titleNumber)")
            }
        }

        let endTime = Date()
        var scriptJob = job
        scriptJob.endTime = endTime
        scriptJob.outputFiles = outputFiles

        if let error = encodeError {
            jobsQueue.async(flags: .barrier) {
                if let idx = self.jobs.firstIndex(where: { $0.id == jobId }) {
                    self.jobs[idx].status = .failed(error)
                    self.jobs[idx].endTime = endTime
                }
                self.isProcessing = false
                self.activeRipper = nil
                Logger.shared.logError(error, context: "Encoding failed for job \(jobId)")
                DispatchQueue.main.async {
                    self.notifyDelegates { $0.queueDidUpdateJobs(self.jobs) }
                    self.notifyDelegates { $0.queueDidFailConversion(jobId: jobId, error: error) }
                }
            }
        } else {
            jobsQueue.async(flags: .barrier) {
                if let idx = self.jobs.firstIndex(where: { $0.id == jobId }) {
                    self.jobs[idx].status = .completed
                    self.jobs[idx].outputFiles = outputFiles
                    self.jobs[idx].endTime = endTime
                    self.jobs[idx].progress = 1.0
                }
                // A successful rip supersedes earlier failed/cancelled attempts of the
                // same disc — prune them so they don't linger in the queue view.
                self.jobs.removeAll { other in
                    guard other.id != jobId, other.sourcePath == job.sourcePath else { return false }
                    switch other.status {
                    case .failed, .cancelled: return true
                    default: return false
                    }
                }
                self.writeRipCompleteMarker(job: job, outputFiles: outputFiles)
                self.isProcessing = false
                self.activeRipper = nil
                Logger.shared.logQueue("Job \(jobId) fully complete: \(outputFiles.count) file(s)", level: .info)
                DispatchQueue.main.async {
                    self.notifyDelegates { $0.queueDidUpdateJobs(self.jobs) }
                    self.notifyDelegates { $0.queueDidCompleteConversion(jobId: jobId, outputFiles: outputFiles) }
                }
            }
            ScriptRunner.shared.runHook(.postProcessing, job: scriptJob, outputFiles: outputFiles)
        }

        processNextJob()
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

/// Bridges MediaRipper delegate callbacks into ConversionQueue state.
/// onComplete fires when the disc is fully read (sectors piped to ffmpeg) — not when encoding finishes.
private class QueueRipperDelegate: MediaRipperDelegate {
    let jobId: UUID
    weak var queue: ConversionQueue?
    private let onComplete: () -> Void
    private let onFail: (Error) -> Void

    init(jobId: UUID, queue: ConversionQueue, onComplete: @escaping () -> Void, onFail: @escaping (Error) -> Void) {
        self.jobId = jobId
        self.queue = queue
        self.onComplete = onComplete
        self.onFail = onFail
    }

    func mediaRipperDidStart() {
        DispatchQueue.main.async {
            self.queue?.notifyDelegates { $0.queueDidUpdateConversionStatus(jobId: self.jobId, status: "Reading disc...") }
        }
    }

    func mediaRipperDidUpdateStatus(_ status: String) {
        DispatchQueue.main.async {
            self.queue?.notifyDelegates { $0.queueDidUpdateConversionStatus(jobId: self.jobId, status: status) }
        }
    }

    func mediaRipperDidUpdateProgress(_ progress: Double, currentItem: MediaRipper.MediaItem?, totalItems: Int) {
        queue?.setJobProgress(id: jobId, progress: progress)
        DispatchQueue.main.async {
            self.queue?.notifyDelegates { $0.queueDidUpdateConversionProgress(jobId: self.jobId, progress: progress) }
        }
    }

    func mediaRipperDidComplete() {
        onComplete()
    }

    func mediaRipperDidFail(with error: Error) {
        onFail(error)
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
