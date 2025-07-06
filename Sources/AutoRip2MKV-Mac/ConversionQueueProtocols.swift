import Foundation

// MARK: - Delegates

protocol ConversionQueueDelegate: AnyObject {
    func queueDidUpdateJobs(_ jobs: [ConversionQueue.ConversionJob])
    func queueDidCompleteJob(_ job: ConversionQueue.ConversionJob)
    func queueDidFailJob(_ job: ConversionQueue.ConversionJob, error: Error)
}

protocol ConversionQueueEjectionDelegate: AnyObject {
    func queueShouldEjectDisc(sourcePath: String)
}
