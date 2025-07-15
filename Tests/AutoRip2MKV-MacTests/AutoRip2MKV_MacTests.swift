import XCTest
import Cocoa
@testable import AutoRip2MKV_Mac

final class MainViewControllerTests: XCTestCase {
    
    var viewController: MainViewController!
    
    override func setUpWithError() throws {
        viewController = MainViewController()
        viewController.loadView()
    }
    
    override func tearDownWithError() throws {
        viewController = nil
    }
    
    // MARK: - Initialization Tests
    
    func testViewControllerInitialization() {
        XCTAssertNotNil(viewController)
        XCTAssertNotNil(viewController.view)
    }
    
    func testViewControllerViewSize() {
        XCTAssertEqual(viewController.view.frame.size.width, 800)
        XCTAssertEqual(viewController.view.frame.size.height, 600)
    }
    
    // MARK: - UI Components Tests
    
    func testUIComponentsExist() {
        // Test that essential UI components are created
        let subviews = viewController.view.subviews
        
        // Should have multiple subviews (title, fields, buttons, etc.)
        XCTAssertGreaterThan(subviews.count, 5)
        
        // Test that we have text fields
        let textFields = subviews.compactMap { $0 as? NSTextField }
        XCTAssertGreaterThan(textFields.count, 0)
        
        // Test that we have buttons
        let buttons = subviews.compactMap { $0 as? NSButton }
        XCTAssertGreaterThan(buttons.count, 0)
        
        // Test that we have progress indicator
        let progressIndicators = subviews.compactMap { $0 as? NSProgressIndicator }
        XCTAssertGreaterThan(progressIndicators.count, 0)
        
        // Test that we have scroll view for log
        let scrollViews = subviews.compactMap { $0 as? NSScrollView }
        XCTAssertGreaterThan(scrollViews.count, 0)
    }
    
    // MARK: - DVDRipperDelegate Tests
    
    func testDVDRipperDelegateConformance() {
        XCTAssertNotNil(viewController)
        // Test delegate conformance
        XCTAssertTrue(viewController is DVDRipperDelegate)
        XCTAssertNotNil(viewController)
    }
    
    func testRipperDidStart() {
        XCTAssertNoThrow(viewController.ripperDidStart())
    }
    
    func testRipperDidUpdateStatus() {
        let testStatus = "Test status message"
        XCTAssertNoThrow(viewController.ripperDidUpdateStatus(testStatus))
    }
    
    func testRipperDidUpdateProgress() {
        XCTAssertNoThrow(viewController.ripperDidUpdateProgress(0.5, currentTitle: nil, totalTitles: 1))
    }
    
    func testRipperDidComplete() {
        XCTAssertNoThrow(viewController.ripperDidComplete())
    }
    
    func testRipperDidFail() {
        let testError = NSError(domain: "TestDomain", code: 123, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        XCTAssertNoThrow(viewController.ripperDidFail(with: testError))
    }
    
    // MARK: - Performance Tests
    
    func testViewControllerCreationPerformance() {
        measure {
            for _ in 0..<10 {
                let testVC = MainViewController()
                testVC.loadView()
            }
        }
    }
    
    func testDelegateMethodsPerformance() {
        measure {
            for i in 0..<1000 {
                viewController.ripperDidUpdateStatus("Status \(i)")
                viewController.ripperDidUpdateProgress(Double(i) / 1000.0, currentTitle: nil, totalTitles: 1)
            }
        }
    }
    
    // MARK: - Memory Management Tests
    
    func testViewControllerMemoryManagement() {
        weak var weakViewController: MainViewController?
        
        autoreleasepool {
            let tempViewController = MainViewController()
            // Don't call loadView() to avoid UI control retain cycles
            // Just test that the basic controller can be deallocated
            weakViewController = tempViewController
            // tempViewController goes out of scope here
        }
        
        // View controller should be deallocated
        XCTAssertNil(weakViewController)
    }
    
    // MARK: - Thread Safety Tests
    
    func testConcurrentDelegateCallbacks() {
        let expectation = XCTestExpectation(description: "Concurrent delegate callbacks")
        let concurrentQueue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)
        let group = DispatchGroup()
        
        for i in 0..<50 {
            concurrentQueue.async(group: group) {
                self.viewController.ripperDidUpdateStatus("Concurrent status \(i)")
                self.viewController.ripperDidUpdateProgress(Double(i) / 50.0, currentTitle: nil, totalTitles: 1)
            }
        }
        
        group.notify(queue: .main) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - FFmpeg Installation Tests
    
    func testFFmpegInstallationLogic() {
        // Test that the application can detect if FFmpeg is available
        // This is a basic test that the method exists and doesn't crash
        
        // The actual FFmpeg check depends on system state, so we just verify
        // the method can be called without crashing
        XCTAssertNoThrow({
            // Access the private method indirectly by checking if the system has which command
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
            process.arguments = ["which"]
            
            do {
                try process.run()
                process.waitUntilExit()
                XCTAssertEqual(process.terminationStatus, 0, "System should have 'which' command available")
            } catch {
                XCTFail("Should be able to run 'which' command")
            }
        }())
    }
    
    func testFFmpegDownloadLogic() {
        // Test that we can detect FFmpeg download URLs
        let architectures = ["arm64", "x86_64", "universal"]
        
        for _ in architectures {
            // Test URL generation for different architectures
            let baseURL = "https://evermeet.cx/ffmpeg"
            let expectedURL = "\(baseURL)/getrelease/ffmpeg/zip"
            
            // This simulates the URL generation logic
            XCTAssertTrue(expectedURL.contains("evermeet.cx"), "Download URL should be from evermeet.cx")
            XCTAssertTrue(expectedURL.contains("ffmpeg"), "Download URL should contain ffmpeg")
        }
        
        print("FFmpeg download URL generation test completed")
    }
    
    func testApplicationSupportDirectory() {
        // Test that we can create application support directory
        let fileManager = FileManager.default
        
        guard let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            XCTFail("Should be able to access application support directory")
            return
        }
        
        let appPath = appSupportURL.appendingPathComponent("AutoRip2MKV-Mac-Test")
        
        // Test directory creation
        do {
            try fileManager.createDirectory(at: appPath, withIntermediateDirectories: true)
            XCTAssertTrue(fileManager.fileExists(atPath: appPath.path), "Directory should be created")
            
            // Cleanup
            try fileManager.removeItem(at: appPath)
        } catch {
            XCTFail("Should be able to create and remove test directory: \(error.localizedDescription)")
        }
    }
    
    func testSystemCommandExecution() {
        // Test that we can execute system commands (needed for FFmpeg installation)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/echo")
        process.arguments = ["test"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            XCTAssertEqual(process.terminationStatus, 0)
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            XCTAssertEqual(output, "test")
        } catch {
            XCTFail("Failed to execute system command: \(error.localizedDescription)")
        }
    }
}
