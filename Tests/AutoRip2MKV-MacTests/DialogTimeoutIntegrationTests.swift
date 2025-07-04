import XCTest
@testable import AutoRip2MKV_Mac

final class DialogTimeoutIntegrationTests: XCTestCase {
    
    var viewController: MainViewController!
    
    override func setUpWithError() throws {
        viewController = MainViewController()
        viewController.loadView()
    }
    
    override func tearDownWithError() throws {
        viewController = nil
    }
    
    // MARK: - Dialog Timeout Tests
    
    func testMainViewControllerAlertsDoNotBlock() {
        let startTime = Date()
        
        // This should complete quickly without user interaction in test environment
        viewController.ripperDidFail(with: NSError(domain: "TestDomain", code: 123, userInfo: [NSLocalizedDescriptionKey: "Test error"]))
        
        let elapsed = Date().timeIntervalSince(startTime)
        
        // Should complete in well under a second since no modal dialog blocks
        XCTAssertLessThan(elapsed, 0.1, "Alert should not block execution in test environment")
    }
    
    func testRipperCompletionAlertsDoNotBlock() {
        let startTime = Date()
        
        // This should complete quickly without user interaction in test environment
        viewController.ripperDidComplete()
        
        let elapsed = Date().timeIntervalSince(startTime)
        
        // Should complete in well under a second since no modal dialog blocks
        XCTAssertLessThan(elapsed, 0.1, "Completion alert should not block execution in test environment")
    }
    
    func testTestingUtilitiesFileDialogSimulation() {
        let startTime = Date()
        
        // Test file panel simulation directly through testing utilities
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.title = "Test Panel"
        
        let result = viewController.testingUtils.showFilePanel(openPanel, testPath: "/tmp/test_path") { _ in }
        
        let elapsed = Date().timeIntervalSince(startTime)
        
        // Should complete reasonably quickly since file panel is simulated in test environment
        XCTAssertLessThan(elapsed, 5.0, "File selection should not block execution in test environment")
        XCTAssertNotNil(result, "Should return simulated path")
        XCTAssertEqual(result?.path, "/tmp/test_path")
    }
    
    // MARK: - Concurrent Dialog Tests
    
    func testMultipleSimultaneousDialogsDoNotBlock() {
        let expectation = XCTestExpectation(description: "Multiple dialogs handled")
        expectation.expectedFulfillmentCount = 5
        
        let startTime = Date()
        
        // Fire multiple delegate callbacks that would normally show dialogs
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            for i in 0..<5 {
                DispatchQueue.main.async {
                    guard let strongSelf = self else {
                        expectation.fulfill()
                        return
                    }
                    strongSelf.viewController.ripperDidFail(with: NSError(domain: "TestDomain", code: i, userInfo: [NSLocalizedDescriptionKey: "Test error \\(i)"]))
                    expectation.fulfill()
                }
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        let elapsed = Date().timeIntervalSince(startTime)
        
        // Should complete reasonably quickly even with multiple dialogs
        XCTAssertLessThan(elapsed, 5.0, "Multiple dialogs should not block execution in test environment")
    }
    
    // MARK: - Test Environment Verification
    
    func testTestEnvironmentIsDetected() {
        // Verify that we're actually running in test environment
        XCTAssertTrue(viewController.isRunningInTestEnvironment, "Should detect test environment")
    }
    
    func testTestingUtilitiesIntegration() {
        // Verify that the testing utilities are working as expected
        let testingUtils = viewController.testingUtils
        XCTAssertNotNil(testingUtils)
        XCTAssertTrue(testingUtils.isRunningInTestEnvironment)
    }
    
    // MARK: - Performance Tests
    
    func testDialogPerformanceInTestEnvironment() {
        measure {
            // This should be very fast in test environment
            for i in 0..<100 {
                viewController.ripperDidUpdateStatus("Status update \\(i)")
                if i % 10 == 0 {
                    viewController.ripperDidFail(with: NSError(domain: "TestDomain", code: i, userInfo: [NSLocalizedDescriptionKey: "Error \\(i)"]))
                }
            }
        }
    }
    
    // MARK: - Edge Cases
    
    func testDialogWithEmptyMessages() {
        let startTime = Date()
        
        // Test with empty error message
        viewController.ripperDidFail(with: NSError(domain: "", code: 0, userInfo: [:]))
        
        let elapsed = Date().timeIntervalSince(startTime)
        XCTAssertLessThan(elapsed, 0.1, "Empty dialog should not block")
    }
    
    func testDialogWithLongMessages() {
        let startTime = Date()
        
        // Test with very long error message
        let longMessage = String(repeating: "This is a very long error message. ", count: 100)
        viewController.ripperDidFail(with: NSError(domain: "TestDomain", code: 999, userInfo: [NSLocalizedDescriptionKey: longMessage]))
        
        let elapsed = Date().timeIntervalSince(startTime)
        XCTAssertLessThan(elapsed, 0.1, "Long message dialog should not block")
    }
    
    // MARK: - Integration with Real Workflow
    
    func testCompleteRippingWorkflowDialogs() {
        let startTime = Date()
        
        // Simulate a complete workflow that would normally show multiple dialogs
        viewController.ripperDidStart()
        viewController.ripperDidUpdateStatus("Starting...")
        viewController.ripperDidUpdateProgress(0.1, currentTitle: nil, totalTitles: 3)
        viewController.ripperDidUpdateProgress(0.5, currentTitle: nil, totalTitles: 3)
        viewController.ripperDidUpdateProgress(1.0, currentTitle: nil, totalTitles: 3)
        viewController.ripperDidComplete()
        
        let elapsed = Date().timeIntervalSince(startTime)
        
        // Complete workflow should not block
        XCTAssertLessThan(elapsed, 0.2, "Complete workflow should not block in test environment")
    }
}
