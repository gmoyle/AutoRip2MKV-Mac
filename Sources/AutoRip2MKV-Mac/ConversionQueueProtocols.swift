import Foundation

// MARK: - Delegates

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
