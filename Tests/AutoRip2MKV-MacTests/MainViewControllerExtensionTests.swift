import XCTest
import Cocoa
@testable import AutoRip2MKV_Mac

final class MainViewControllerExtensionTests: XCTestCase {
    
    var viewController: MainViewController!
    var mockDelegate: MockDVDRipperDelegate!
    let testOutputPath = "/tmp/test_mvc_output"
    
    override func setUpWithError() throws {
        viewController = MainViewController()
        viewController.loadView()
        viewController.setupMockUIForTesting() // Setup mock UI for testing
        mockDelegate = MockDVDRipperDelegate()
        
        // Create test output directory
        try FileManager.default.createDirectory(atPath: testOutputPath, withIntermediateDirectories: true)
    }
    
    override func tearDownWithError() throws {
        viewController = nil
        mockDelegate = nil
        
        // Cleanup
        try? FileManager.default.removeItem(atPath: testOutputPath)
    }
    
    // MARK: - MainViewController+Utilities Tests
    
    func testAppendToLog() {
        let testMessage = "Test log message"
        
        XCTAssertNoThrow(viewController.appendToLog(testMessage))
        
        // Verify the log text view contains the message
        let logContent = viewController.logTextView.string
        XCTAssertTrue(logContent.contains(testMessage), "Log should contain the test message")
        XCTAssertTrue(logContent.contains("["), "Log should contain timestamp brackets")
    }
    
    func testAppendToLogWithTimestamp() {
        // Clear any existing content first
        viewController.logTextView.string = ""
        
        let message1 = "First message"
        let message2 = "Second message"
        
        viewController.appendToLog(message1)
        viewController.appendToLog(message2)
        
        let logContent = viewController.logTextView.string
        XCTAssertTrue(logContent.contains(message1))
        XCTAssertTrue(logContent.contains(message2))
        
        // Should have two timestamp entries
        let timestampCount = logContent.components(separatedBy: "[").count - 1
        XCTAssertEqual(timestampCount, 2, "Should have two timestamp entries")
    }
    
    func testShowAlert() {
        let testTitle = "Test Alert"
        let testMessage = "Test alert message"
        
        // This will be captured by TestingUtilities in test environment
        XCTAssertNoThrow(viewController.showAlert(title: testTitle, message: testMessage))
        
        // In test environment, alert should be logged
        let logContent = viewController.logTextView.string
        XCTAssertTrue(logContent.contains("ALERT"), "Alert should be logged in test environment")
    }
    
    func testFFmpegAvailabilityCheck() {
        // Test that FFmpeg availability check doesn't crash
        XCTAssertNoThrow({
            let isAvailable = viewController.isFFmpegAvailable()
            // Result depends on system state, but method should not crash
            _ = isAvailable
        }())
    }
    
    func testFFmpegPathDetection() {
        // Test FFmpeg path detection
        let ffmpegPath = viewController.getFFmpegExecutablePath()
        
        if let path = ffmpegPath {
            XCTAssertFalse(path.isEmpty, "FFmpeg path should not be empty if found")
            XCTAssertTrue(path.contains("ffmpeg"), "Path should contain 'ffmpeg'")
        }
        // If nil, FFmpeg is not installed, which is acceptable for testing
    }
    
    func testBundledFFmpegPath() {
        let bundledPath = viewController.getBundledFFmpegPath()
        
        if let path = bundledPath {
            XCTAssertTrue(path.contains("Contents/Resources/ffmpeg"), "Bundled path should be in app bundle")
        }
        // Path may be nil if not bundled, which is acceptable
    }
    
    func testInstallFFmpegIfNeeded() {
        // Test that FFmpeg installation logic doesn't crash
        XCTAssertNoThrow(viewController.installFFmpegIfNeeded())
        
        // Should log something about FFmpeg
        let logContent = viewController.logTextView.string
        XCTAssertTrue(logContent.contains("FFmpeg") || logContent.isEmpty, "Should mention FFmpeg or be empty")
    }
    
    func testEjectCurrentDisk() {
        // Test disk ejection without a selected drive
        XCTAssertNoThrow(viewController.ejectCurrentDisk())
        
        // Should log about no drive selected
        let logContent = viewController.logTextView.string
        XCTAssertTrue(logContent.contains("No drive") || logContent.contains("ejection"), "Should log about drive ejection")
    }
    
    func testGetSelectedSourcePath() {
        // Test with no drives detected
        let sourcePath = viewController.getSelectedSourcePath()
        XCTAssertNil(sourcePath, "Should return nil when no drives are detected")
    }
    
    func testLoadSettings() {
        // Test settings loading doesn't crash
        XCTAssertNoThrow(viewController.loadSettings())
        
        // Output field should be accessible after loading
        XCTAssertNotNil(viewController.outputPathField)
    }
    
    func testSaveCurrentSettings() {
        // Set a test output path
        viewController.outputPathField.stringValue = testOutputPath
        
        // Test settings saving doesn't crash
        XCTAssertNoThrow(viewController.saveCurrentSettings())
    }
    
    // MARK: - MainViewController+FFmpeg Tests
    
    func testGetApplicationSupportPath() {
        let appSupportPath = viewController.getApplicationSupportPath()
        
        XCTAssertFalse(appSupportPath.isEmpty, "App support path should not be empty")
        XCTAssertTrue(appSupportPath.contains("AutoRip2MKV-Mac"), "Path should contain app name")
        
        // Verify the directory exists after calling the method
        XCTAssertTrue(FileManager.default.fileExists(atPath: appSupportPath), "Directory should be created")
    }
    
    func testResetRipButton() {
        // Initially set button to different state
        viewController.ripButton.title = "Test Title"
        viewController.ripButton.isEnabled = false
        
        viewController.resetRipButton()
        
        XCTAssertEqual(viewController.ripButton.title, "Start Ripping", "Button title should be reset")
        XCTAssertTrue(viewController.ripButton.isEnabled, "Button should be enabled")
    }
    
    func testDownloadAndInstallFFmpeg() {
        // Test that download doesn't crash (won't actually download in test)
        XCTAssertNoThrow(viewController.downloadAndInstallFFmpeg())
        
        // Should log about downloading
        let logContent = viewController.logTextView.string
        XCTAssertTrue(logContent.contains("Downloading") || logContent.contains("FFmpeg"), 
                     "Should log about FFmpeg download")
    }
    
    // MARK: - MainViewController+Delegates Tests
    
    func testDVDRipperDelegateImplementation() {
        // Test that all delegate methods exist and can be called
        XCTAssertNoThrow(viewController.ripperDidStart())
        XCTAssertNoThrow(viewController.ripperDidUpdateStatus("Test status"))
        XCTAssertNoThrow(viewController.ripperDidUpdateProgress(0.5, currentTitle: nil, totalTitles: 1))
        XCTAssertNoThrow(viewController.ripperDidComplete())
        
        let testError = NSError(domain: "TestDomain", code: 123, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        XCTAssertNoThrow(viewController.ripperDidFail(with: testError))
    }
    
    func testDelegateMethodsUpdateUI() {
        // Test that delegate methods update the UI appropriately
        viewController.ripperDidStart()
        
        // Should log the start
        var logContent = viewController.logTextView.string
        XCTAssertTrue(logContent.contains("started"), "Should log ripper start")
        
        // Test status update
        let testStatus = "Test status update"
        viewController.ripperDidUpdateStatus(testStatus)
        
        logContent = viewController.logTextView.string
        XCTAssertTrue(logContent.contains(testStatus), "Should log status update")
        
        // Test progress update
        viewController.ripperDidUpdateProgress(0.75, currentTitle: nil, totalTitles: 1)
        XCTAssertEqual(viewController.progressIndicator.doubleValue, 75.0, "Progress should be updated")
        
        // Test completion
        viewController.ripperDidComplete()
        XCTAssertTrue(viewController.progressIndicator.isHidden, "Progress should be hidden on completion")
        XCTAssertTrue(viewController.ripButton.isEnabled, "Rip button should be enabled on completion")
    }
    
    func testDelegateErrorHandling() {
        let testError = NSError(domain: "TestDomain", code: 456, userInfo: [NSLocalizedDescriptionKey: "Test error message"])
        
        viewController.ripperDidFail(with: testError)
        
        // Should reset UI state
        XCTAssertTrue(viewController.progressIndicator.isHidden, "Progress should be hidden on error")
        XCTAssertTrue(viewController.ripButton.isEnabled, "Rip button should be enabled on error")
        XCTAssertEqual(viewController.ripButton.title, "Start Ripping", "Button title should be reset")
        
        // Should log the error
        let logContent = viewController.logTextView.string
        XCTAssertTrue(logContent.contains("Error"), "Should log error")
        XCTAssertTrue(logContent.contains("Test error message"), "Should log error message")
    }
    
    func testMediaRipperDelegateImplementation() {
        // Create a test media item for progress updates
        let testTitle = DVDTitle(number: 1, vtsNumber: 1, vtsTitleNumber: 1, startSector: 100, chapters: 5, angles: 1, duration: 3600)
        let mediaItem = MediaRipper.MediaItem.dvdTitle(testTitle)
        
        XCTAssertNoThrow(viewController.ripperDidUpdateProgress(0.6, currentItem: mediaItem, totalItems: 3))
        
        // Should update progress
        XCTAssertEqual(viewController.progressIndicator.doubleValue, 60.0, "Progress should be updated")
        
        // Should log progress with title information
        let logContent = viewController.logTextView.string
        XCTAssertTrue(logContent.contains("title 1"), "Should log title information")
    }
    
    // MARK: - Integration Tests
    
    func testUIComponentsAfterExtensionMethods() {
        // Test that UI components remain functional after extension method calls
        viewController.appendToLog("Test message 1")
        viewController.ripperDidUpdateStatus("Status update")
        viewController.ripperDidUpdateProgress(0.3, currentTitle: nil, totalTitles: 1)
        
        // UI should still be responsive
        XCTAssertNotNil(viewController.logTextView.string)
        XCTAssertEqual(viewController.progressIndicator.doubleValue, 30.0)
        
        viewController.ripperDidComplete()
        
        // State should be properly reset
        XCTAssertTrue(viewController.progressIndicator.isHidden)
        XCTAssertTrue(viewController.ripButton.isEnabled)
    }
    
    func testConcurrentDelegateUpdates() {
        let expectation = XCTestExpectation(description: "Concurrent delegate updates")
        let concurrentQueue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)
        let group = DispatchGroup()
        
        // Fire multiple concurrent updates
        for i in 0..<20 {
            concurrentQueue.async(group: group) {
                DispatchQueue.main.async {
                    self.viewController.ripperDidUpdateStatus("Concurrent status \(i)")
                    self.viewController.ripperDidUpdateProgress(Double(i) / 20.0, currentTitle: nil, totalTitles: 1)
                }
            }
        }
        
        group.notify(queue: .main) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // Should handle concurrent updates without crashing
        XCTAssertNotNil(viewController.logTextView.string)
        XCTAssertGreaterThanOrEqual(viewController.progressIndicator.doubleValue, 0)
    }
    
    // MARK: - Performance Tests
    
    func testLogAppendPerformance() {
        measure {
            for i in 0..<100 {
                viewController.appendToLog("Performance test message \(i)")
            }
        }
    }
    
    func testDelegateMethodPerformance() {
        measure {
            for i in 0..<1000 {
                viewController.ripperDidUpdateProgress(Double(i) / 1000.0, currentTitle: nil, totalTitles: 1)
            }
        }
    }
    
    // MARK: - Memory Management Tests
    
    func testExtensionMethodsMemoryManagement() {
        weak var weakViewController: MainViewController?
        
        autoreleasepool {
            let tempViewController = MainViewController()
            tempViewController.loadView()
            weakViewController = tempViewController
            
            // Call extension methods
            tempViewController.appendToLog("Memory test")
            tempViewController.ripperDidStart()
            tempViewController.ripperDidComplete()
            tempViewController.installFFmpegIfNeeded()
            
            // tempViewController goes out of scope here
        }
        
        // Should be deallocated
        XCTAssertNil(weakViewController, "View controller should be deallocated")
    }
}

// MARK: - Test Helpers

private extension MainViewController {
    // Helper for testing - checks if UI components are accessible
    var hasUIComponentsInitialized: Bool {
        return logTextView != nil && progressIndicator != nil && ripButton != nil && outputPathField != nil
    }
    
    // Mock UI components for testing when real ones aren't available
    func setupMockUIForTesting() {
        // Create mock UI components if they don't exist
        if logTextView == nil {
            logTextView = NSTextView()
        }
        if progressIndicator == nil {
            progressIndicator = NSProgressIndicator()
        }
        if ripButton == nil {
            ripButton = NSButton()
            ripButton.title = "Start Ripping"
        }
        if outputPathField == nil {
            outputPathField = NSTextField()
        }
        if sourceDropDown == nil {
            sourceDropDown = NSPopUpButton()
        }
    }
}
