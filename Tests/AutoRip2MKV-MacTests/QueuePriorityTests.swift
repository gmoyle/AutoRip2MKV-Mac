//
//  QueuePriorityTests.swift
//  AutoRip2MKV-MacTests
//
//  Tests for queue priority system and enhanced time estimation
//

import XCTest
@testable import AutoRip2MKV_Mac

final class QueuePriorityTests: XCTestCase {
    
    var queue: ConversionQueue!
    
    override func setUp() {
        super.setUp()
        queue = ConversionQueue(testMode: true)
    }
    
    override func tearDown() {
        queue = nil
        super.tearDown()
    }
    
    // MARK: - Priority Enum Tests
    
    func testPriorityComparison() {
        XCTAssertTrue(ConversionQueue.JobPriority.urgent > .high)
        XCTAssertTrue(ConversionQueue.JobPriority.high > .normal)
        XCTAssertTrue(ConversionQueue.JobPriority.normal > .low)
        XCTAssertFalse(ConversionQueue.JobPriority.low > .normal)
    }
    
    func testPriorityDescription() {
        XCTAssertEqual(ConversionQueue.JobPriority.urgent.description, "Urgent")
        XCTAssertEqual(ConversionQueue.JobPriority.high.description, "High")
        XCTAssertEqual(ConversionQueue.JobPriority.normal.description, "Normal")
        XCTAssertEqual(ConversionQueue.JobPriority.low.description, "Low")
    }
    
    // MARK: - Job Priority Tests
    
    func testJobCreationWithDefaultPriority() {
        let config = createTestConfiguration()
        _ = queue.addJob(
            sourcePath: "/Volumes/DVD",
            outputDirectory: "/tmp/output",
            configuration: config,
            mediaType: .dvd,
            discTitle: "Test Disc"
        )
        
        let jobs = queue.getAllJobs()
        XCTAssertEqual(jobs.count, 1)
        XCTAssertEqual(jobs[0].priority, .normal)
    }
    
    func testJobCreationWithSpecificPriority() {
        let config = createTestConfiguration()
        _ = queue.addJob(
            sourcePath: "/Volumes/DVD",
            outputDirectory: "/tmp/output",
            configuration: config,
            mediaType: .dvd,
            discTitle: "Urgent Disc",
            priority: .urgent
        )
        
        let jobs = queue.getAllJobs()
        XCTAssertEqual(jobs.count, 1)
        XCTAssertEqual(jobs[0].priority, .urgent)
    }
    
    func testUpdateJobPriority() {
        let config = createTestConfiguration()
        let jobId = queue.addJob(
            sourcePath: "/Volumes/DVD",
            outputDirectory: "/tmp/output",
            configuration: config,
            mediaType: .dvd,
            discTitle: "Test Disc",
            priority: .low
        )
        
        queue.updateJobPriority(jobId: jobId, priority: .urgent)
        
        let jobs = queue.getAllJobs()
        XCTAssertEqual(jobs[0].priority, .urgent)
    }
    
    // MARK: - Time Estimation Tests
    
    func testJobDurationEstimation_DVD_H264() {
        let config = createTestConfiguration(codec: .h264)
        _ = queue.addJob(
            sourcePath: "/Volumes/DVD",
            outputDirectory: "/tmp/output",
            configuration: config,
            mediaType: .dvd,
            discTitle: "DVD H264"
        )
        
        let jobs = queue.getAllJobs()
        XCTAssertNotNil(jobs[0].estimatedDuration)
        if let duration = jobs[0].estimatedDuration {
            XCTAssertEqual(duration, 1800.0, accuracy: 0.1) // 30 minutes
        }
    }
    
    func testJobDurationEstimation_DVD_AV1() {
        let config = createTestConfiguration(codec: .av1)
        _ = queue.addJob(
            sourcePath: "/Volumes/DVD",
            outputDirectory: "/tmp/output",
            configuration: config,
            mediaType: .dvd,
            discTitle: "DVD AV1"
        )
        
        let jobs = queue.getAllJobs()
        XCTAssertNotNil(jobs[0].estimatedDuration)
        if let duration = jobs[0].estimatedDuration {
            XCTAssertEqual(duration, 5400.0, accuracy: 0.1) // 30 min * 3x = 90 min
        }
    }
    
    func testJobDurationEstimation_BluRay4K_H265() {
        let config = createTestConfiguration(codec: .h265)
        _ = queue.addJob(
            sourcePath: "/Volumes/BLURAY",
            outputDirectory: "/tmp/output",
            configuration: config,
            mediaType: .bluray4K,
            discTitle: "4K UHD"
        )
        
        let jobs = queue.getAllJobs()
        XCTAssertNotNil(jobs[0].estimatedDuration)
        if let duration = jobs[0].estimatedDuration {
            XCTAssertEqual(duration, 8100.0, accuracy: 0.1) // 90 min * 1.5x = 135 min
        }
    }
    
    func testJobDurationEstimation_HDDVD_VP9() {
        let config = createTestConfiguration(codec: .vp9)
        _ = queue.addJob(
            sourcePath: "/Volumes/HDDVD",
            outputDirectory: "/tmp/output",
            configuration: config,
            mediaType: .hddvd,
            discTitle: "HD DVD"
        )
        
        let jobs = queue.getAllJobs()
        XCTAssertNotNil(jobs[0].estimatedDuration)
        if let duration = jobs[0].estimatedDuration {
            XCTAssertEqual(duration, 4800.0, accuracy: 0.1) // 40 min * 2x = 80 min
        }
    }
    
    // MARK: - Priority Sorting Tests
    
    func testMultipleJobsPrioritySorting() {
        let config = createTestConfiguration()
        
        // Add jobs with different priorities
        _ = queue.addJob(
            sourcePath: "/Volumes/DVD1",
            outputDirectory: "/tmp/output",
            configuration: config,
            mediaType: .dvd,
            discTitle: "Low Priority",
            priority: .low
        )
        
        Thread.sleep(forTimeInterval: 0.01) // Ensure different addedTime
        
        _ = queue.addJob(
            sourcePath: "/Volumes/DVD2",
            outputDirectory: "/tmp/output",
            configuration: config,
            mediaType: .dvd,
            discTitle: "High Priority",
            priority: .high
        )
        
        Thread.sleep(forTimeInterval: 0.01)
        
        _ = queue.addJob(
            sourcePath: "/Volumes/DVD3",
            outputDirectory: "/tmp/output",
            configuration: config,
            mediaType: .dvd,
            discTitle: "Urgent Priority",
            priority: .urgent
        )
        
        Thread.sleep(forTimeInterval: 0.01)
        
        _ = queue.addJob(
            sourcePath: "/Volumes/DVD4",
            outputDirectory: "/tmp/output",
            configuration: config,
            mediaType: .dvd,
            discTitle: "Normal Priority",
            priority: .normal
        )
        
        let jobs = queue.getAllJobs()
        XCTAssertEqual(jobs.count, 4)
        
        // Verify jobs are added in order (not yet sorted)
        XCTAssertEqual(jobs[0].discTitle, "Low Priority")
        XCTAssertEqual(jobs[1].discTitle, "High Priority")
        XCTAssertEqual(jobs[2].discTitle, "Urgent Priority")
        XCTAssertEqual(jobs[3].discTitle, "Normal Priority")
        
        // Sort by priority (as processNextJob does)
        let sortedJobs = jobs.sorted { job1, job2 in
            if job1.priority != job2.priority {
                return job1.priority > job2.priority
            }
            return job1.addedTime < job2.addedTime
        }
        
        // Verify correct priority order
        XCTAssertEqual(sortedJobs[0].discTitle, "Urgent Priority")
        XCTAssertEqual(sortedJobs[1].discTitle, "High Priority")
        XCTAssertEqual(sortedJobs[2].discTitle, "Normal Priority")
        XCTAssertEqual(sortedJobs[3].discTitle, "Low Priority")
    }
    
    func testSamePrioritySortsByAddedTime() {
        let config = createTestConfiguration()
        
        // Add multiple jobs with same priority
        _ = queue.addJob(
            sourcePath: "/Volumes/DVD1",
            outputDirectory: "/tmp/output",
            configuration: config,
            mediaType: .dvd,
            discTitle: "First",
            priority: .normal
        )
        
        Thread.sleep(forTimeInterval: 0.01)
        
        _ = queue.addJob(
            sourcePath: "/Volumes/DVD2",
            outputDirectory: "/tmp/output",
            configuration: config,
            mediaType: .dvd,
            discTitle: "Second",
            priority: .normal
        )
        
        Thread.sleep(forTimeInterval: 0.01)
        
        _ = queue.addJob(
            sourcePath: "/Volumes/DVD3",
            outputDirectory: "/tmp/output",
            configuration: config,
            mediaType: .dvd,
            discTitle: "Third",
            priority: .normal
        )
        
        let jobs = queue.getAllJobs()
        let sortedJobs = jobs.sorted { job1, job2 in
            if job1.priority != job2.priority {
                return job1.priority > job2.priority
            }
            return job1.addedTime < job2.addedTime
        }
        
        // Verify FIFO order for same priority
        XCTAssertEqual(sortedJobs[0].discTitle, "First")
        XCTAssertEqual(sortedJobs[1].discTitle, "Second")
        XCTAssertEqual(sortedJobs[2].discTitle, "Third")
        XCTAssertTrue(sortedJobs[0].addedTime < sortedJobs[1].addedTime)
        XCTAssertTrue(sortedJobs[1].addedTime < sortedJobs[2].addedTime)
    }
    
    // MARK: - Helper Methods
    
    private func createTestConfiguration(codec: MediaRipper.RippingConfiguration.VideoCodec = .h264) -> MediaRipper.RippingConfiguration {
        return MediaRipper.RippingConfiguration(
            outputDirectory: "/tmp/output",
            selectedTitles: [],
            videoCodec: codec,
            audioCodec: .aac,
            quality: .medium,
            includeSubtitles: true,
            includeChapters: true,
            mediaType: nil
        )
    }
}
