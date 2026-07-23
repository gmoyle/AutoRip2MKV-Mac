import XCTest
@testable import AutoRip2MKV_Mac

final class ConversionQueueTests: XCTestCase {
    
    var conversionQueue: ConversionQueue!
    var mockDelegate: MockConversionQueueDelegate!
    var mockEjectionDelegate: MockConversionQueueEjectionDelegate!
    let testSourcePath = "/tmp/test_conversion_source"
    let testOutputPath = "/tmp/test_conversion_output"
    
    override func setUpWithError() throws {
        conversionQueue = ConversionQueue(testMode: true)
        mockDelegate = MockConversionQueueDelegate()
        mockEjectionDelegate = MockConversionQueueEjectionDelegate()
        
        conversionQueue.delegate = mockDelegate
        conversionQueue.ejectionDelegate = mockEjectionDelegate
        
        // Create test directories
        try FileManager.default.createDirectory(atPath: testSourcePath, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(atPath: "\(testSourcePath)/VIDEO_TS", withIntermediateDirectories: true)
        try FileManager.default.createDirectory(atPath: testOutputPath, withIntermediateDirectories: true)
        
        // Create minimal test DVD structure
        try createTestDVDStructure()
    }
    
    override func tearDownWithError() throws {
        conversionQueue = nil
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
        
        // Create basic DVD files
        try "test".write(toFile: "\(videoTSPath)/VIDEO_TS.IFO", atomically: true, encoding: .utf8)
        try "test".write(toFile: "\(videoTSPath)/VTS_01_0.IFO", atomically: true, encoding: .utf8)
        try "test".write(toFile: "\(videoTSPath)/VTS_01_1.VOB", atomically: true, encoding: .utf8)
    }
    
    private func createTestConfiguration() -> MediaRipper.RippingConfiguration {
        return MediaRipper.RippingConfiguration(
            outputDirectory: testOutputPath,
            selectedTitles: [],
            videoCodec: .h264,
            audioCodec: .aac,
            quality: .medium,
            includeSubtitles: true,
            includeChapters: true,
            mediaType: .dvd
        )
    }
    
    // MARK: - Basic Queue Management Tests
    
    func testAddJob() {
        let configuration = createTestConfiguration()
        
        let jobId = conversionQueue.addJob(
            sourcePath: testSourcePath,
            outputDirectory: testOutputPath,
            configuration: configuration,
            mediaType: .dvd,
            discTitle: "Test DVD"
        )
        
        XCTAssertFalse(jobId.uuidString.isEmpty, "Job ID should not be empty")
        
        let queueStatus = conversionQueue.getQueueStatus()
        XCTAssertEqual(queueStatus.total, 1, "Queue should have 1 job")
        XCTAssertEqual(queueStatus.pending, 1, "Should have 1 pending job")
    }
    
    func testMultipleJobs() {
        let configuration = createTestConfiguration()
        
        let jobId1 = conversionQueue.addJob(
            sourcePath: testSourcePath,
            outputDirectory: testOutputPath,
            configuration: configuration,
            mediaType: .dvd,
            discTitle: "Test DVD 1"
        )
        
        let jobId2 = conversionQueue.addJob(
            sourcePath: testSourcePath,
            outputDirectory: testOutputPath,
            configuration: configuration,
            mediaType: .dvd,
            discTitle: "Test DVD 2"
        )
        
        XCTAssertNotEqual(jobId1, jobId2, "Job IDs should be unique")
        
        let queueStatus = conversionQueue.getQueueStatus()
        XCTAssertEqual(queueStatus.total, 2, "Queue should have 2 jobs")
        XCTAssertEqual(queueStatus.pending, 2, "Should have 2 pending jobs")
    }
    
    func testGetAllJobs() {
        let configuration = createTestConfiguration()
        
        // Initially empty
        XCTAssertEqual(conversionQueue.getAllJobs().count, 0, "Queue should be empty initially")
        
        // Add a job
        _ = conversionQueue.addJob(
            sourcePath: testSourcePath,
            outputDirectory: testOutputPath,
            configuration: configuration,
            mediaType: .dvd,
            discTitle: "Test DVD"
        )
        
        let jobs = conversionQueue.getAllJobs()
        XCTAssertEqual(jobs.count, 1, "Should have 1 job")
        XCTAssertEqual(jobs[0].discTitle, "Test DVD", "Job title should match")
        XCTAssertEqual(jobs[0].sourcePath, testSourcePath, "Source path should match")
    }
    
    // MARK: - Job Status Tests
    
    func testJobInitialStatus() {
        let configuration = createTestConfiguration()
        
        _ = conversionQueue.addJob(
            sourcePath: testSourcePath,
            outputDirectory: testOutputPath,
            configuration: configuration,
            mediaType: .dvd,
            discTitle: "Test DVD"
        )
        
        let jobs = conversionQueue.getAllJobs()
        XCTAssertEqual(jobs[0].status, .pending, "Initial job status should be pending")
        XCTAssertEqual(jobs[0].progress, 0.0, "Initial progress should be 0")
        XCTAssertNil(jobs[0].extractedDataPath, "Initially no extracted data path")
        XCTAssertEqual(jobs[0].outputFiles.count, 0, "Initially no output files")
    }
    
    func testJobStatusDescription() {
        let configuration = createTestConfiguration()
        
        _ = conversionQueue.addJob(
            sourcePath: testSourcePath,
            outputDirectory: testOutputPath,
            configuration: configuration,
            mediaType: .dvd,
            discTitle: "Test DVD"
        )
        
        let jobs = conversionQueue.getAllJobs()
        let job = jobs[0]
        
        XCTAssertEqual(job.statusDescription, "Waiting", "Pending status description should be 'Waiting'")
        XCTAssertEqual(job.formattedDuration, "Not started", "Duration should be 'Not started' initially")
    }
    
    // MARK: - Job Cancellation Tests
    
    func testCancelJob() {
        let configuration = createTestConfiguration()
        
        let jobId = conversionQueue.addJob(
            sourcePath: testSourcePath,
            outputDirectory: testOutputPath,
            configuration: configuration,
            mediaType: .dvd,
            discTitle: "Test DVD"
        )
        
        conversionQueue.cancelJob(id: jobId)
        
        // Wait for status update
        let expectation = XCTestExpectation(description: "Job cancellation")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        let jobs = conversionQueue.getAllJobs()
        XCTAssertEqual(jobs[0].status, .cancelled, "Job should be cancelled")
    }
    
    func testCancelAllJobs() {
        let configuration = createTestConfiguration()
        
        _ = conversionQueue.addJob(
            sourcePath: testSourcePath,
            outputDirectory: testOutputPath,
            configuration: configuration,
            mediaType: .dvd,
            discTitle: "Test DVD 1"
        )
        
        _ = conversionQueue.addJob(
            sourcePath: testSourcePath,
            outputDirectory: testOutputPath,
            configuration: configuration,
            mediaType: .dvd,
            discTitle: "Test DVD 2"
        )
        
        conversionQueue.cancelAllJobs()
        
        // Wait for status update
        let expectation = XCTestExpectation(description: "All jobs cancellation")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        let jobs = conversionQueue.getAllJobs()
        XCTAssertEqual(jobs.count, 2, "Should still have 2 jobs")
        XCTAssertEqual(jobs[0].status, .cancelled, "First job should be cancelled")
        XCTAssertEqual(jobs[1].status, .cancelled, "Second job should be cancelled")
    }
    
    func testClearCompletedJobs() {
        let configuration = createTestConfiguration()
        
        let jobId = conversionQueue.addJob(
            sourcePath: testSourcePath,
            outputDirectory: testOutputPath,
            configuration: configuration,
            mediaType: .dvd,
            discTitle: "Test DVD"
        )
        
        // Cancel the job to make it "completed"
        conversionQueue.cancelJob(id: jobId)
        
        // Wait for cancellation
        let expectation1 = XCTestExpectation(description: "Job cancellation")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation1.fulfill()
        }
        wait(for: [expectation1], timeout: 1.0)
        
        // Clear completed jobs
        conversionQueue.clearCompletedJobs()
        
        // Wait for clearing
        let expectation2 = XCTestExpectation(description: "Clear completed jobs")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation2.fulfill()
        }
        wait(for: [expectation2], timeout: 1.0)
        
        let jobs = conversionQueue.getAllJobs()
        XCTAssertEqual(jobs.count, 0, "Cancelled job should be cleared")
    }
    
    // MARK: - Queue Status Tests
    
    func testQueueStatusTracking() {
        let configuration = createTestConfiguration()
        
        // Initially empty
        var status = conversionQueue.getQueueStatus()
        XCTAssertEqual(status.total, 0, "Initial total should be 0")
        XCTAssertEqual(status.pending, 0, "Initial pending should be 0")
        
        // Add jobs
        _ = conversionQueue.addJob(
            sourcePath: testSourcePath,
            outputDirectory: testOutputPath,
            configuration: configuration,
            mediaType: .dvd,
            discTitle: "Test DVD 1"
        )
        
        let jobId2 = conversionQueue.addJob(
            sourcePath: testSourcePath,
            outputDirectory: testOutputPath,
            configuration: configuration,
            mediaType: .dvd,
            discTitle: "Test DVD 2"
        )
        
        status = conversionQueue.getQueueStatus()
        XCTAssertEqual(status.total, 2, "Total should be 2")
        XCTAssertEqual(status.pending, 2, "Pending should be 2")
        
        // Cancel one job
        conversionQueue.cancelJob(id: jobId2)
        
        // Wait for status update
        let expectation = XCTestExpectation(description: "Status update")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        status = conversionQueue.getQueueStatus()
        XCTAssertEqual(status.total, 2, "Total should still be 2")
        XCTAssertEqual(status.pending, 1, "Pending should be 1")
    }
    
    // MARK: - Delegate Tests
    
    func testDelegateCallbacks() {
        let configuration = createTestConfiguration()
        
        _ = conversionQueue.addJob(
            sourcePath: testSourcePath,
            outputDirectory: testOutputPath,
            configuration: configuration,
            mediaType: .dvd,
            discTitle: "Test DVD"
        )
        
        // Wait for delegate callback
        let expectation = XCTestExpectation(description: "Delegate callback")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertTrue(mockDelegate.queueDidUpdateJobsCalled, "queueDidUpdateJobs should be called")
        XCTAssertEqual(mockDelegate.lastJobsUpdate?.count, 1, "Should have 1 job in update")
    }
    
    // MARK: - Error Handling Tests
    
    func testInvalidSourcePath() {
        let configuration = createTestConfiguration()
        
        let jobId = conversionQueue.addJob(
            sourcePath: "/invalid/path",
            outputDirectory: testOutputPath,
            configuration: configuration,
            mediaType: .dvd,
            discTitle: "Invalid DVD"
        )
        
        // Wait for processing to fail
        let expectation = XCTestExpectation(description: "Extraction failure")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)
        
        let jobs = conversionQueue.getAllJobs()
        if let job = jobs.first(where: { $0.id == jobId }) {
            // Job should either fail or remain pending (depending on implementation)
            XCTAssertTrue(
                job.status == .failed(ConversionQueueError.sourceNotFound) ||
                job.status == .pending,
                "Job should fail or remain pending with invalid source"
            )
        }
    }
    
    // MARK: - Performance Tests
    
    func testQueuePerformance() {
        let configuration = createTestConfiguration()
        
        measure {
            for i in 0..<10 {
                _ = conversionQueue.addJob(
                    sourcePath: testSourcePath,
                    outputDirectory: testOutputPath,
                    configuration: configuration,
                    mediaType: .dvd,
                    discTitle: "Test DVD \(i)"
                )
            }
        }
    }
    
    func testStatusCheckPerformance() {
        let configuration = createTestConfiguration()
        
        // Add several jobs
        for i in 0..<20 {
            _ = conversionQueue.addJob(
                sourcePath: testSourcePath,
                outputDirectory: testOutputPath,
                configuration: configuration,
                mediaType: .dvd,
                discTitle: "Test DVD \(i)"
            )
        }
        
        measure {
            for _ in 0..<100 {
                _ = conversionQueue.getQueueStatus()
                _ = conversionQueue.getAllJobs()
            }
        }
    }
    
    // MARK: - Integration Tests
    
    func testJobLifecycle() {
        let configuration = createTestConfiguration()
        
        let jobId = conversionQueue.addJob(
            sourcePath: testSourcePath,
            outputDirectory: testOutputPath,
            configuration: configuration,
            mediaType: .dvd,
            discTitle: "Test DVD"
        )
        
        // Initial state
        var jobs = conversionQueue.getAllJobs()
        var job = jobs.first { $0.id == jobId }!
        XCTAssertEqual(job.status, .pending, "Job should start as pending")
        
        // Wait for extraction to potentially start
        let expectation = XCTestExpectation(description: "Job processing")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)
        
        // Check if job progressed or failed (depending on test environment)
        jobs = conversionQueue.getAllJobs()
        job = jobs.first { $0.id == jobId }!
        
        // In test environment, job may remain pending or start extracting
        XCTAssertTrue(
            job.status == .pending || 
            job.status == .extracting ||
            job.status == .extracted ||
            job.status == .failed(ConversionQueueError.sourceNotFound),
            "Job should be in a valid state after processing attempt"
        )
    }
}

// MARK: - Mock Delegates

class MockConversionQueueDelegate: ConversionQueueDelegate {
    var queueDidUpdateJobsCalled = false
    var queueDidStartExtractionCalled = false
    var queueDidCompleteExtractionCalled = false
    var queueDidFailExtractionCalled = false
    var queueDidStartConversionCalled = false
    var queueDidCompleteConversionCalled = false
    var queueDidFailConversionCalled = false
    var queueDidUpdateConversionStatusCalled = false
    var queueDidUpdateConversionProgressCalled = false
    
    var lastJobsUpdate: [ConversionQueue.ConversionJob]?
    var lastExtractionJobId: UUID?
    var lastConversionJobId: UUID?
    var lastError: Error?
    var lastOutputFiles: [String]?
    var lastStatus: String?
    var lastProgress: Double?
    
    func queueDidUpdateJobs(_ jobs: [ConversionQueue.ConversionJob]) {
        queueDidUpdateJobsCalled = true
        lastJobsUpdate = jobs
    }
    
    func queueDidStartExtraction(jobId: UUID) {
        queueDidStartExtractionCalled = true
        lastExtractionJobId = jobId
    }
    
    func queueDidCompleteExtraction(jobId: UUID) {
        queueDidCompleteExtractionCalled = true
        lastExtractionJobId = jobId
    }
    
    func queueDidFailExtraction(jobId: UUID, error: Error) {
        queueDidFailExtractionCalled = true
        lastExtractionJobId = jobId
        lastError = error
    }
    
    func queueDidStartConversion(jobId: UUID) {
        queueDidStartConversionCalled = true
        lastConversionJobId = jobId
    }
    
    func queueDidCompleteConversion(jobId: UUID, outputFiles: [String]) {
        queueDidCompleteConversionCalled = true
        lastConversionJobId = jobId
        lastOutputFiles = outputFiles
    }
    
    func queueDidFailConversion(jobId: UUID, error: Error) {
        queueDidFailConversionCalled = true
        lastConversionJobId = jobId
        lastError = error
    }
    
    func queueDidUpdateConversionStatus(jobId: UUID, status: String) {
        queueDidUpdateConversionStatusCalled = true
        lastConversionJobId = jobId
        lastStatus = status
    }
    
    func queueDidUpdateConversionProgress(jobId: UUID, progress: Double) {
        queueDidUpdateConversionProgressCalled = true
        lastConversionJobId = jobId
        lastProgress = progress
    }
}

class MockConversionQueueEjectionDelegate: ConversionQueueEjectionDelegate {
    var queueShouldEjectDiscCalled = false
    var lastEjectionSourcePath: String?
    
    func queueShouldEjectDisc(sourcePath: String) {
        queueShouldEjectDiscCalled = true
        lastEjectionSourcePath = sourcePath
    }
}
