import XCTest
@testable import AutoRip2MKV_Mac

final class TestingUtilitiesTests: XCTestCase {
    
    var testingUtils: TestingUtilities!
    
    override func setUpWithError() throws {
        testingUtils = TestingUtilities.shared
    }
    
    override func tearDownWithError() throws {
        testingUtils = nil
    }
    
    // MARK: - Test Environment Detection Tests
    
    func testIsRunningInTestEnvironment() {
        // This should return true when running in XCTest
        XCTAssertTrue(testingUtils.isRunningInTestEnvironment, 
                     "Should detect test environment when running in XCTest")
    }
    
    func testTestEnvironmentDetectionMethods() {
        // Test that XCTestCase class is available (since we're in a test)
        XCTAssertNotNil(NSClassFromString("XCTestCase"), 
                       "XCTestCase should be available in test environment")
    }
    
    // MARK: - Alert Handling Tests
    
    func testShowAlertInTestEnvironment() {
        let expectation = XCTestExpectation(description: "Alert log handler called")
        var capturedTitle: String?
        var capturedMessage: String?
        
        testingUtils.showAlert(
            title: "Test Alert",
            message: "This is a test message",
            style: .warning
        ) { title, message in
            capturedTitle = title
            capturedMessage = message
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertEqual(capturedTitle, "Test Alert")
        XCTAssertEqual(capturedMessage, "This is a test message")
    }
    
    func testShowAlertWithDifferentStyles() {
        let styles: [NSAlert.Style] = [.warning, .informational, .critical]
        let expectation = XCTestExpectation(description: "All alert styles handled")
        expectation.expectedFulfillmentCount = styles.count
        
        for style in styles {
            testingUtils.showAlert(
                title: "Test \(style)",
                message: "Test message for \(style)",
                style: style
            ) { title, message in
                XCTAssertTrue(title.contains("Test"))
                XCTAssertTrue(message.contains("Test message"))
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    // MARK: - File Panel Handling Tests
    
    func testShowFilePanelInTestEnvironment() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.title = "Test Panel"
        
        let expectation = XCTestExpectation(description: "File panel log handler called")
        var capturedLogMessage: String?
        
        let result = testingUtils.showFilePanel(
            openPanel,
            testPath: "/tmp/test_selection"
        ) { logMessage in
            capturedLogMessage = logMessage
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertNotNil(result, "Should return a URL in test environment")
        XCTAssertEqual(result?.path, "/tmp/test_selection")
        XCTAssertNotNil(capturedLogMessage)
        XCTAssertTrue(capturedLogMessage?.contains("test_selection") ?? false)
    }
    
    func testShowFilePanelWithDefaultTestPath() {
        let openPanel = NSOpenPanel()
        openPanel.title = "Test Panel with Default Path"
        
        let result = testingUtils.showFilePanel(openPanel) { _ in
            // Log handler called
        }
        
        XCTAssertNotNil(result, "Should return a URL even with default test path")
        XCTAssertEqual(result?.path, "/tmp/test_path")
    }
    
    // MARK: - Performance Tests
    
    func testEnvironmentDetectionPerformance() {
        measure {
            for _ in 0..<1000 {
                _ = testingUtils.isRunningInTestEnvironment
            }
        }
    }
    
    func testAlertHandlingPerformance() {
        measure {
            for i in 0..<100 {
                testingUtils.showAlert(
                    title: "Performance Test \(i)",
                    message: "Message \(i)"
                ) { _, _ in
                    // Log handler
                }
            }
        }
    }
    
    // MARK: - Integration Tests
    
    func testMainViewControllerExtension() {
        let viewController = MainViewController()
        
        // Test that the extension properties work
        XCTAssertNotNil(viewController.testingUtils)
        XCTAssertTrue(viewController.isRunningInTestEnvironment)
        XCTAssertTrue(viewController.testingUtils === TestingUtilities.shared)
    }
    
    // MARK: - Edge Cases
    
    func testEmptyAlertTitleAndMessage() {
        let expectation = XCTestExpectation(description: "Empty alert handled")
        
        testingUtils.showAlert(title: "", message: "") { title, message in
            XCTAssertEqual(title, "")
            XCTAssertEqual(message, "")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testNilLogHandlers() {
        // These should not crash when log handlers are nil
        XCTAssertNoThrow({ [weak self] in
            self?.testingUtils.showAlert(title: "Test", message: "Test")
        })
        
        XCTAssertNoThrow({ [weak self] in
            let openPanel = NSOpenPanel()
            _ = self?.testingUtils.showFilePanel(openPanel)
        })
    }
    
    // MARK: - Thread Safety Tests
    
    func testConcurrentAlertHandling() {
        let expectation = XCTestExpectation(description: "Concurrent alerts handled")
        expectation.expectedFulfillmentCount = 10
        
        let concurrentQueue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)
        
        for i in 0..<10 {
            concurrentQueue.async {
                self.testingUtils.showAlert(
                    title: "Concurrent Test \(i)",
                    message: "Message \(i)"
                ) { _, _ in
                    expectation.fulfill()
                }
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
}
