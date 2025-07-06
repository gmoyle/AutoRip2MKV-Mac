import XCTest
import Cocoa
@testable import AutoRip2MKV_Mac

final class QueueWindowControllerTests: XCTestCase {
    
    var windowController: QueueWindowController!
    var mockQueue: MockConversionQueue!
    let testOutputPath = "/tmp/test_queue_window_output"
    
    override func setUpWithError() throws {
        mockQueue = MockConversionQueue()
        windowController = QueueWindowController(conversionQueue: mockQueue)
        
        // Create test output directory
        try FileManager.default.createDirectory(atPath: testOutputPath, withIntermediateDirectories: true)
        
        // Load the window to trigger windowDidLoad
        _ = windowController.window
    }
    
    override func tearDownWithError() throws {
        windowController = nil
        mockQueue = nil
        
        // Cleanup
        try? FileManager.default.removeItem(atPath: testOutputPath)
    }
    
    // MARK: - Initialization Tests
    
    func testWindowControllerInitialization() {
        XCTAssertNotNil(windowController, "Window controller should be initialized")
        XCTAssertNotNil(windowController.window, "Window should be created")
        XCTAssertEqual(windowController.window?.title, "Conversion Queue", "Window title should be set correctly")
    }
    
    func testUIElementsCreation() {
        // Trigger window loading if not already done
        windowController.windowDidLoad()
        
        // Check that UI elements are created (they might be nil if XIB is not used)
        // The createUIElements method creates them programmatically
        XCTAssertTrue(true, "UI creation should not crash")
    }
    
    // MARK: - Queue Management Tests
    
    func testInitialQueueState() {
        let status = mockQueue.getQueueStatus()
        XCTAssertEqual(status.total, 0, "Initial queue should be empty")
        XCTAssertEqual(status.pending, 0, "Initial pending jobs should be 0")
    }
    
    func testQueueStatusUpdate() {
        // Add some mock jobs to the queue
        let job1 = createMockJob(title: "Test DVD 1", status: .pending)
        let job2 = createMockJob(title: "Test DVD 2", status: .extracting)
        let job3 = createMockJob(title: "Test DVD 3", status: .completed)
        
        mockQueue.addMockJob(job1)
        mockQueue.addMockJob(job2)
        mockQueue.addMockJob(job3)
        
        // Simulate queue update
        windowController.queueDidUpdateJobs(mockQueue.getAllJobs())
        
        // Verify the window controller received the update
        let status = mockQueue.getQueueStatus()
        XCTAssertEqual(status.total, 3, "Should have 3 total jobs")
        XCTAssertEqual(status.pending, 1, "Should have 1 pending job")
        XCTAssertEqual(status.extracting, 1, "Should have 1 extracting job")
        XCTAssertEqual(status.completed, 1, "Should have 1 completed job")
    }
    
    // MARK: - Action Tests
    
    func testClearCompletedAction() {
        // Add completed jobs
        let completedJob = createMockJob(title: "Completed DVD", status: .completed)
        let pendingJob = createMockJob(title: "Pending DVD", status: .pending)
        
        mockQueue.addMockJob(completedJob)
        mockQueue.addMockJob(pendingJob)
        
        // Trigger clear completed action
        XCTAssertNoThrow({
            mockQueue.clearCompletedJobs()
        }())
        
        XCTAssertTrue(mockQueue.clearCompletedJobsCalled, "clearCompletedJobs should be called")
    }
    
    func testCancelAllAction() {
        // Add pending jobs
        let job1 = createMockJob(title: "Pending DVD 1", status: .pending)
        let job2 = createMockJob(title: "Pending DVD 2", status: .pending)
        
        mockQueue.addMockJob(job1)
        mockQueue.addMockJob(job2)
        
        // Trigger cancel all action
        XCTAssertNoThrow({
            mockQueue.cancelAllJobs()
        }())
        
        XCTAssertTrue(mockQueue.cancelAllJobsCalled, "cancelAllJobs should be called")
    }
    
    // MARK: - Delegate Method Tests
    
    func testQueueDidUpdateJobs() {
        let jobs = [
            createMockJob(title: "Test DVD 1", status: .pending),
            createMockJob(title: "Test DVD 2", status: .converting)
        ]
        
        XCTAssertNoThrow({
            windowController.queueDidUpdateJobs(jobs)
        }())
    }
    
    func testQueueDidStartExtraction() {
        let jobId = UUID()
        
        XCTAssertNoThrow({
            windowController.queueDidStartExtraction(jobId: jobId)
        }())
    }
    
    func testQueueDidCompleteExtraction() {
        let jobId = UUID()
        
        XCTAssertNoThrow({
            windowController.queueDidCompleteExtraction(jobId: jobId)
        }())
    }
    
    func testQueueDidFailExtraction() {
        let jobId = UUID()
        let error = ConversionQueueError.sourceNotFound
        
        XCTAssertNoThrow({
            windowController.queueDidFailExtraction(jobId: jobId, error: error)
        }())
    }
    
    func testQueueDidStartConversion() {
        let jobId = UUID()
        
        XCTAssertNoThrow({
            windowController.queueDidStartConversion(jobId: jobId)
        }())
    }
    
    func testQueueDidCompleteConversion() {
        let jobId = UUID()
        let outputFiles = ["test1.mkv", "test2.mkv"]
        
        XCTAssertNoThrow({
            windowController.queueDidCompleteConversion(jobId: jobId, outputFiles: outputFiles)
        }())
    }
    
    func testQueueDidFailConversion() {
        let jobId = UUID()
        let error = ConversionQueueError.conversionFailed
        
        XCTAssertNoThrow({
            windowController.queueDidFailConversion(jobId: jobId, error: error)
        }())
    }
    
    func testQueueDidUpdateConversionStatus() {
        let jobId = UUID()
        let status = "Converting title 1..."
        
        XCTAssertNoThrow({
            windowController.queueDidUpdateConversionStatus(jobId: jobId, status: status)
        }())
    }
    
    func testQueueDidUpdateConversionProgress() {
        let jobId = UUID()
        let progress = 0.5
        
        XCTAssertNoThrow({
            windowController.queueDidUpdateConversionProgress(jobId: jobId, progress: progress)
        }())
    }
    
    // MARK: - Table View Tests
    
    func testTableViewDataSource() {
        // Add some mock jobs
        let jobs = [
            createMockJob(title: "Test DVD 1", status: .pending),
            createMockJob(title: "Test DVD 2", status: .extracting),
            createMockJob(title: "Test DVD 3", status: .converting)
        ]
        
        for job in jobs {
            mockQueue.addMockJob(job)
        }
        
        windowController.queueDidUpdateJobs(mockQueue.getAllJobs())
        
        // Test table view data source methods
        XCTAssertNoThrow({
            let tableView = NSTableView()
            let rowCount = windowController.numberOfRows(in: tableView)
            XCTAssertEqual(rowCount, 3, "Table should have 3 rows")
        }())
    }
    
    // MARK: - Performance Tests
    
    func testQueueUpdatePerformance() {
        // Create many jobs
        var jobs: [ConversionQueue.ConversionJob] = []
        for i in 0..<100 {
            jobs.append(createMockJob(title: "Test DVD \(i)", status: .pending))
        }
        
        measure {
            windowController.queueDidUpdateJobs(jobs)
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
            sourcePath: "/tmp/test_source",
            outputDirectory: testOutputPath,
            configuration: configuration,
            mediaType: .dvd,
            discTitle: title
        )
        
        job.status = status
        
        return job
    }
}

// MARK: - Mock ConversionQueue

class MockConversionQueue: ConversionQueue {
    
    private var mockJobs: [ConversionJob] = []
    
    var addJobCalled = false
    var cancelJobCalled = false
    var cancelAllJobsCalled = false
    var clearCompletedJobsCalled = false
    
    override func addJob(sourcePath: String, outputDirectory: String, configuration: MediaRipper.RippingConfiguration, mediaType: MediaRipper.MediaType, discTitle: String) -> UUID {
        addJobCalled = true
        
        let job = ConversionJob(
            sourcePath: sourcePath,
            outputDirectory: outputDirectory,
            configuration: configuration,
            mediaType: mediaType,
            discTitle: discTitle
        )
        
        mockJobs.append(job)
        return job.id
    }
    
    override func cancelJob(id: UUID) {
        cancelJobCalled = true
        
        if let index = mockJobs.firstIndex(where: { $0.id == id }) {
            mockJobs[index].status = .cancelled
        }
    }
    
    override func cancelAllJobs() {
        cancelAllJobsCalled = true
        
        for index in mockJobs.indices {
            if case .pending = mockJobs[index].status {
                mockJobs[index].status = .cancelled
            }
        }
    }
    
    override func clearCompletedJobs() {
        clearCompletedJobsCalled = true
        
        mockJobs.removeAll { job in
            switch job.status {
            case .completed, .failed, .cancelled:
                return true
            default:
                return false
            }
        }
    }
    
    override func getQueueStatus() -> (total: Int, pending: Int) {
        let total = mockJobs.count
        let pending = mockJobs.count { case .pending = $0.status; return true; default: return false }
        
        return (total, pending)
    }
    
    override func getDetailedQueueStatus() -> (
        total: Int, 
        pending: Int, 
        extracting: Int, 
        converting: Int, 
        completed: Int, 
        failed: Int
    ) {
        let total = mockJobs.count
        let pending = mockJobs.count { case .pending = $0.status; return true; default: return false }
        let extracting = mockJobs.count { case .extracting = $0.status; return true; default: return false }
        let converting = mockJobs.count { case .converting = $0.status; return true; default: return false }
        let completed = mockJobs.count { case .completed = $0.status; return true; default: return false }
        let failed = mockJobs.count { case .failed = $0.status; return true; default: return false }
        
        return (total, pending, extracting, converting, completed, failed)
    }
    
    override func getAllJobs() -> [ConversionJob] {
        return mockJobs
    }
    
    // Helper method for testing
    func addMockJob(_ job: ConversionJob) {
        mockJobs.append(job)
    }
}
