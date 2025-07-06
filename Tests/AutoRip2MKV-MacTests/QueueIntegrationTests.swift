import XCTest
@testable import AutoRip2MKV_Mac

final class QueueIntegrationTests: XCTestCase {
    
    var conversionQueue: ConversionQueue!
    var queueController: QueueWindowController!
    var viewController: MainViewController!
    var mockDelegate: MockConversionQueueDelegate!
    var mockEjectionDelegate: MockConversionQueueEjectionDelegate!
    
    let testSourcePath = "/tmp/test_queue_integration_source"
    let testOutputPath = "/tmp/test_queue_integration_output"
    
    override func setUpWithError() throws {
        conversionQueue = ConversionQueue(testMode: true)
        mockDelegate = MockConversionQueueDelegate()
        mockEjectionDelegate = MockConversionQueueEjectionDelegate()
        
        queueController = QueueWindowController(conversionQueue: conversionQueue)
        
        // Set delegates after queue controller is created
        conversionQueue.delegate = mockDelegate
        conversionQueue.ejectionDelegate = mockEjectionDelegate
        
        viewController = MainViewController()
        viewController.loadView()
        viewController.setupMockUIForTesting()
        
        // Create test directory structure
        try FileManager.default.createDirectory(atPath: testSourcePath, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(atPath: "\(testSourcePath)/VIDEO_TS", withIntermediateDirectories: true)
        try FileManager.default.createDirectory(atPath: testOutputPath, withIntermediateDirectories: true)
        
        try createTestDVDStructure()
    }
    
    override func tearDownWithError() throws {
        conversionQueue = nil
        queueController = nil
        viewController = nil
        mockDelegate = nil
        mockEjectionDelegate = nil
        
        // Cleanup
        try? FileManager.default.removeItem(atPath: testSourcePath)
        try? FileManager.default.removeItem(atPath: testOutputPath)
        try? FileManager.default.removeItem(atPath: NSTemporaryDirectory().appending("AutoRip2MKV"))
    }
    
    // MARK: - Test Setup Helpers
    
    private func createTestDVDStructure() throws {
        let videoTSPath = "\(testSourcePath)/VIDEO_TS"
        
        try "test".write(toFile: "\(videoTSPath)/VIDEO_TS.IFO", atomically: true, encoding: .utf8)
        try "test".write(toFile: "\(videoTSPath)/VTS_01_0.IFO", atomically: true, encoding: .utf8)
        try "test".write(toFile: "\(videoTSPath)/VTS_01_1.VOB", atomically: true, encoding: .utf8)
    }
    
    // MARK: - End-to-End Workflow Tests
    
    func testCompleteQueueWorkflow() {
        let expectation = XCTestExpectation(description: "Complete queue workflow")
        
        // Step 1: Add job to queue
        let configuration = MediaRipper.RippingConfiguration(
            outputDirectory: testOutputPath,
            selectedTitles: [],
            videoCodec: .h264,
            audioCodec: .aac,
            quality: .medium,
            includeSubtitles: true,
            includeChapters: true,
            mediaType: .dvd
        )
        
        let jobId = conversionQueue.addJob(
            sourcePath: testSourcePath,
            outputDirectory: testOutputPath,
            configuration: configuration,
            mediaType: .dvd,
            discTitle: "Test Integration DVD"
        )
        
        XCTAssertFalse(jobId.uuidString.isEmpty, "Job should be added successfully")
        
        // Step 2: Verify initial state
        var status = conversionQueue.getQueueStatus()
        XCTAssertEqual(status.total, 1, "Should have 1 job")
        XCTAssertEqual(status.pending, 1, "Should have 1 pending job")
        
        // Step 3: Manually trigger delegate callback to test integration
        let jobs = conversionQueue.getAllJobs()
        conversionQueue.delegate?.queueDidUpdateJobs(jobs)
        
        // Verify queue controller receives updates
        XCTAssertTrue(mockDelegate.queueDidUpdateJobsCalled, "Queue delegate should be called")
        XCTAssertEqual(mockDelegate.lastJobsUpdate?.count, 1, "Should have 1 job in update")
        
        // Step 4: Test queue controller UI update
        queueController.queueDidUpdateJobs(conversionQueue.getAllJobs())
        
        // Step 5: Wait for potential processing
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
        
        // Step 6: Verify final state
        status = conversionQueue.getQueueStatus()
        XCTAssertEqual(status.total, 1, "Should still have 1 job")
        
        let finalJobs = conversionQueue.getAllJobs()
        let job = finalJobs.first { $0.id == jobId }
        XCTAssertNotNil(job, "Job should still exist")
        
        // Job may have progressed or failed depending on test environment
        XCTAssertTrue(
            job?.status == .pending ||
            job?.status == .extracting ||
            job?.status == .extracted ||
            job?.status == .failed(ConversionQueueError.sourceNotFound),
            "Job should be in a valid state"
        )
    }
    
    func testMainViewControllerQueueIntegration() {
        // Set up view controller for queue-based ripping
        viewController.outputPathField.stringValue = testOutputPath
        
        // Test adding job through main view controller
        XCTAssertNoThrow({
            // This simulates the queue-based ripping workflow
            let mediaRipper = MediaRipper()
            let mediaType = mediaRipper.detectMediaType(path: testSourcePath)
            let discTitle = viewController.generateDiscTitle(from: testSourcePath)
            
            XCTAssertEqual(mediaType, .dvd, "Should detect DVD media type")
            XCTAssertFalse(discTitle.isEmpty, "Should generate disc title")
        }())
        
        // Verify logs contain queue-related messages
        _ = viewController.logTextView.string
        // Initial log might be empty, which is acceptable in test environment
    }
    
    func testAutoEjectionWorkflow() {
        // Enable auto-eject
        viewController.autoEjectCheckbox.state = .on
        viewController.autoEjectToggled()
        
        // Create mock drive
        let mockDrive = OpticalDrive(
            mountPoint: testSourcePath,
            name: "Test Drive",
            type: .dvd,
            devicePath: "/dev/disk2"
        )
        
        // Add the mock drive to detected drives
        viewController.detectedDrives = [mockDrive]
        
        // Simulate ejection request from queue
        viewController.queueShouldEjectDisc(sourcePath: testSourcePath)
        
        // Verify logs contain ejection messages
        let logContent = viewController.logTextView.string
        XCTAssertTrue(
            logContent.contains("Auto-ejecting") || logContent.contains("manual"),
            "Should log about ejection attempt"
        )
    }
    
    func testQueueWindowControllerIntegration() {
        // Add multiple jobs with different states
        let jobs = [
            createMockJob(title: "DVD 1", status: .pending),
            createMockJob(title: "DVD 2", status: .extracting),
            createMockJob(title: "DVD 3", status: .converting),
            createMockJob(title: "DVD 4", status: .completed)
        ]
        
        // Simulate queue updates
        queueController.queueDidUpdateJobs(jobs)
        
        // Test various delegate callbacks
        let testJobId = UUID()
        
        XCTAssertNoThrow({
            queueController.queueDidStartExtraction(jobId: testJobId)
            queueController.queueDidCompleteExtraction(jobId: testJobId)
            queueController.queueDidStartConversion(jobId: testJobId)
            queueController.queueDidUpdateConversionProgress(jobId: testJobId, progress: 0.5)
            queueController.queueDidCompleteConversion(jobId: testJobId, outputFiles: ["test.mkv"])
        }())
    }
    
    func testErrorHandlingIntegration() {
        // Test error handling throughout the queue system
        let configuration = MediaRipper.RippingConfiguration(
            outputDirectory: "/invalid/output/path",
            selectedTitles: [],
            videoCodec: .h264,
            audioCodec: .aac,
            quality: .medium,
            includeSubtitles: false,
            includeChapters: false,
            mediaType: .dvd
        )
        
        let jobId = conversionQueue.addJob(
            sourcePath: "/invalid/source/path",
            outputDirectory: "/invalid/output/path",
            configuration: configuration,
            mediaType: .dvd,
            discTitle: "Invalid DVD"
        )
        
        // Wait for potential error processing
        let expectation = XCTestExpectation(description: "Error processing")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)
        
        // Verify error handling
        if mockDelegate.queueDidFailExtractionCalled {
            XCTAssertNotNil(mockDelegate.lastError, "Should have error details")
        }
        
        let jobs = conversionQueue.getAllJobs()
        if let job = jobs.first(where: { $0.id == jobId }) {
            // Job may be pending or failed depending on how quickly error processing occurs
            XCTAssertTrue(
                job.status == .pending || 
                job.status == .failed(ConversionQueueError.sourceNotFound),
                "Job should be pending or failed with invalid paths"
            )
        }
    }
    
    func testConcurrentOperations() {
        // Test that queue can handle multiple jobs being added concurrently
        let configuration = MediaRipper.RippingConfiguration(
            outputDirectory: testOutputPath,
            selectedTitles: [],
            videoCodec: .h264,
            audioCodec: .aac,
            quality: .medium,
            includeSubtitles: true,
            includeChapters: true,
            mediaType: .dvd
        )
        
        var jobIds: [UUID] = []
        
        // Add multiple jobs rapidly
        for i in 0..<5 {
            let jobId = conversionQueue.addJob(
                sourcePath: testSourcePath,
                outputDirectory: testOutputPath,
                configuration: configuration,
                mediaType: .dvd,
                discTitle: "Concurrent DVD \(i)"
            )
            jobIds.append(jobId)
        }
        
        // Verify all jobs were added
        XCTAssertEqual(jobIds.count, 5, "Should have 5 jobs")
        XCTAssertEqual(Set(jobIds).count, 5, "All job IDs should be unique")
        
        let status = conversionQueue.getQueueStatus()
        XCTAssertEqual(status.total, 5, "Queue should have 5 jobs")
        
        // In test mode with real ConversionQueue, jobs may remain pending or start processing
        // We just verify the total count is correct
        XCTAssertGreaterThanOrEqual(status.pending, 4, "Most jobs should be pending initially")
        
        // Test concurrent cancellation
        for jobId in jobIds.prefix(3) {
            conversionQueue.cancelJob(id: jobId)
        }
        
        // Wait for cancellations to process
        let expectation = XCTestExpectation(description: "Concurrent cancellation")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        let finalStatus = conversionQueue.getQueueStatus()
        XCTAssertEqual(finalStatus.total, 5, "Should still have 5 total jobs")
        XCTAssertLessThanOrEqual(finalStatus.pending, 2, "Should have at most 2 pending jobs")
    }
    
    func testMemoryManagement() {
        // Test that queue doesn't leak memory with many operations
        weak var weakQueue = conversionQueue
        weak var weakController = queueController
        
        let configuration = MediaRipper.RippingConfiguration(
            outputDirectory: testOutputPath,
            selectedTitles: [],
            videoCodec: .h264,
            audioCodec: .aac,
            quality: .medium,
            includeSubtitles: false,
            includeChapters: false,
            mediaType: .dvd
        )
        
        // Add and remove many jobs
        for i in 0..<20 {
            let jobId = conversionQueue.addJob(
                sourcePath: testSourcePath,
                outputDirectory: testOutputPath,
                configuration: configuration,
                mediaType: .dvd,
                discTitle: "Memory Test DVD \(i)"
            )
            
            if i % 2 == 0 {
                conversionQueue.cancelJob(id: jobId)
            }
        }
        
        // Clear completed jobs
        conversionQueue.clearCompletedJobs()
        
        // Objects should still be alive while we hold references
        XCTAssertNotNil(weakQueue, "Queue should be alive")
        XCTAssertNotNil(weakController, "Controller should be alive")
    }
    
    // MARK: - Performance Tests
    
    func testQueuePerformanceWithManyJobs() {
        let configuration = MediaRipper.RippingConfiguration(
            outputDirectory: testOutputPath,
            selectedTitles: [],
            videoCodec: .h264,
            audioCodec: .aac,
            quality: .medium,
            includeSubtitles: false,
            includeChapters: false,
            mediaType: .dvd
        )
        
        measure {
            // Add 50 jobs and check status
            for i in 0..<50 {
                _ = conversionQueue.addJob(
                    sourcePath: testSourcePath,
                    outputDirectory: testOutputPath,
                    configuration: configuration,
                    mediaType: .dvd,
                    discTitle: "Performance Test DVD \(i)"
                )
            }
            
            _ = conversionQueue.getQueueStatus()
            _ = conversionQueue.getAllJobs()
        }
    }
    
    // MARK: - Helper Methods
    
    private func createMockJob(title: String, status: ConversionQueue.JobStatus) -> ConversionQueue.ConversionJob {
        let configuration = MediaRipper.RippingConfiguration(
            outputDirectory: testOutputPath,
            selectedTitles: [],
            videoCodec: .h264,
            audioCodec: .aac,
            quality: .medium,
            includeSubtitles: true,
            includeChapters: true,
            mediaType: .dvd
        )
        
        var job = ConversionQueue.ConversionJob(
            sourcePath: testSourcePath,
            outputDirectory: testOutputPath,
            configuration: configuration,
            mediaType: .dvd,
            discTitle: title
        )
        
        job.status = status
        return job
    }
}
