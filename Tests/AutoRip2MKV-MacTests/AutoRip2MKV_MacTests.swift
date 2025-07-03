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
        XCTAssertTrue(viewController is DVDRipperDelegate)
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
            tempViewController.loadView()
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
}
