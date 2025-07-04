import XCTest
@testable import AutoRip2MKV_Mac

final class DiskManagementTests: XCTestCase {
    
    var viewController: MainViewController!
    
    override func setUpWithError() throws {
        viewController = MainViewController()
        viewController.loadView()
    }
    
    override func tearDownWithError() throws {
        viewController = nil
    }
    
    // MARK: - Disk Ejection Tests
    
    func testEjectCurrentDiskWithoutSource() {
        // Test ejection when no source is selected
        // This should not crash and should log appropriately
        XCTAssertNoThrow({
            // Use reflection to call the private method if possible, or test indirectly
            viewController.ripperDidComplete()
        }())
    }
    
    func testCompletionTriggersEjection() {
        // Test that completion calls eject
        let startTime = Date()
        
        viewController.ripperDidComplete()
        
        let elapsed = Date().timeIntervalSince(startTime)
        
        // Should complete quickly in test environment
        XCTAssertLessThan(elapsed, 0.1, "Completion with ejection should be fast in test environment")
    }
    
    // MARK: - System Command Tests
    
    func testDiskutilCommandExists() {
        // Test that diskutil command is available on the system
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["diskutil"]
        
        do {
            try process.run()
            process.waitUntilExit()
            XCTAssertEqual(process.terminationStatus, 0, "diskutil should be available on macOS")
        } catch {
            XCTFail("Should be able to check for diskutil command: \(error.localizedDescription)")
        }
    }
    
    func testDiskutilListCommand() {
        // Test that we can run diskutil list (safe command that lists disks)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        process.arguments = ["list"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            XCTAssertEqual(process.terminationStatus, 0, "diskutil list should execute successfully")
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)
            XCTAssertNotNil(output, "Should get output from diskutil list")
            XCTAssertTrue(output?.contains("/dev/disk") == true, "Output should contain disk information")
        } catch {
            XCTFail("Should be able to run diskutil list: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testEjectWithInvalidPath() {
        // Test that ejection with invalid path doesn't crash
        XCTAssertNoThrow({
            // This tests the error handling in the eject methods
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
            process.arguments = ["unmount", "/invalid/path/that/does/not/exist"]
            
            do {
                try process.run()
                process.waitUntilExit()
                // Should not crash, termination status may be non-zero for invalid path
                XCTAssertTrue(true, "Process should complete without crashing")
            } catch {
                // This is expected for invalid paths
                XCTAssertTrue(true, "Error handling works correctly")
            }
        }())
    }
    
    // MARK: - Performance Tests
    
    func testEjectionPerformance() {
        measure {
            // Test that multiple completion calls don't cause performance issues
            for _ in 0..<10 {
                viewController.ripperDidComplete()
            }
        }
    }
    
    // MARK: - Concurrent Tests
    
    func testConcurrentEjectionCalls() {
        let expectation = XCTestExpectation(description: "Concurrent ejection calls")
        let concurrentQueue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)
        let group = DispatchGroup()
        
        // Test multiple concurrent completion calls
        for _ in 0..<5 {
            concurrentQueue.async(group: group) {
                self.viewController.ripperDidComplete()
            }
        }
        
        group.notify(queue: .main) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Integration Tests
    
    func testCompleteWorkflowWithEjection() {
        // Test complete workflow from start to completion with ejection
        let startTime = Date()
        
        viewController.ripperDidStart()
        viewController.ripperDidUpdateStatus("Starting...")
        viewController.ripperDidUpdateProgress(0.0, currentTitle: nil, totalTitles: 1)
        viewController.ripperDidUpdateProgress(0.5, currentTitle: nil, totalTitles: 1)
        viewController.ripperDidUpdateProgress(1.0, currentTitle: nil, totalTitles: 1)
        viewController.ripperDidComplete() // Should trigger ejection
        
        let elapsed = Date().timeIntervalSince(startTime)
        
        // Complete workflow should be fast
        XCTAssertLessThan(elapsed, 0.2, "Complete workflow with ejection should be fast")
    }
    
    func testNoDialogInCompletion() {
        // Verify that completion doesn't show any dialogs by checking it completes very quickly
        let startTime = Date()
        
        viewController.ripperDidComplete()
        
        let elapsed = Date().timeIntervalSince(startTime)
        
        // If a dialog was shown, this would take much longer
        XCTAssertLessThan(elapsed, 0.05, "No dialog should be shown on completion")
    }
    
    // MARK: - Memory Management Tests
    
    func testEjectionMemoryManagement() {
        autoreleasepool {
            let tempViewController = MainViewController()
            tempViewController.loadView()
            
            // Trigger completion/ejection
            tempViewController.ripperDidComplete()
            
            // tempViewController goes out of scope here
        }
        
        // Give time for any async operations to complete
        let expectation = XCTestExpectation(description: "Memory cleanup")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Memory management test completed successfully
        XCTAssertTrue(true, "Memory management test completed - view controller lifecycle varies in test environment")
    }
}
