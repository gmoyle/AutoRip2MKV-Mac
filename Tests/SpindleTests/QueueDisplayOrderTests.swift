import XCTest
@testable import Spindle

/// The main window's queue table lists the newest job first.
final class QueueDisplayOrderTests: XCTestCase {

    private func job(_ title: String, addedSecondsAgo: TimeInterval, now: Date) -> ConversionQueue.ConversionJob {
        let config = MediaRipper.RippingConfiguration(
            outputDirectory: "/tmp", selectedTitles: [], videoCodec: .h264, audioCodec: .aac,
            quality: .high, includeSubtitles: true, includeChapters: true, mediaType: nil)
        var job = ConversionQueue.ConversionJob(
            sourcePath: "/Volumes/\(title)", outputDirectory: "/tmp/output", configuration: config,
            mediaType: .dvd, discTitle: title)
        job.addedTime = now.addingTimeInterval(-addedSecondsAgo)
        return job
    }

    func testNewestJobIsListedFirst() {
        let now = Date()
        let jobs = [job("First", addedSecondsAgo: 300, now: now),
                    job("Second", addedSecondsAgo: 200, now: now),
                    job("Third", addedSecondsAgo: 100, now: now)]
        XCTAssertEqual(MainViewController.newestFirst(jobs).map(\.discTitle), ["Third", "Second", "First"])
    }

    func testOrdersByAddedTimeNotQueuePosition() {
        // Priority can move an older job later in the queue; display still goes by age.
        let now = Date()
        let jobs = [job("Newer", addedSecondsAgo: 10, now: now),
                    job("Older", addedSecondsAgo: 500, now: now)]
        XCTAssertEqual(MainViewController.newestFirst(jobs).map(\.discTitle), ["Newer", "Older"])
    }

    func testSameAddedTimeReversesQueueOrder() {
        let now = Date()
        let jobs = [job("A", addedSecondsAgo: 0, now: now), job("B", addedSecondsAgo: 0, now: now)]
        XCTAssertEqual(MainViewController.newestFirst(jobs).map(\.discTitle), ["B", "A"])
    }
}
