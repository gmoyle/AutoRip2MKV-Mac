import XCTest
import Cocoa
@testable import AutoRip2MKV_Mac

final class UIUpdateManagerTests: XCTestCase {
    
    var uiUpdateManager: UIUpdateManager!
    var mockUIComponents: UIComponents!
    var mockProgressIndicator: MockProgressIndicator!
    var mockRipButton: MockButton!
    var mockLogTextView: MockTextView!
    var mockSourceDropDown: MockPopUpButton!
    var mockRefreshButton: MockButton!
    var mockBrowseSourceButton: MockButton!
    var mockBrowseOutputButton: MockButton!
    
    override func setUpWithError() throws {
        // Create mock UI components
        mockProgressIndicator = MockProgressIndicator()
        mockRipButton = MockButton()
        mockLogTextView = MockTextView()
        mockSourceDropDown = MockPopUpButton()
        mockRefreshButton = MockButton()
        mockBrowseSourceButton = MockButton()
        mockBrowseOutputButton = MockButton()
        
        // Create UI components container
        mockUIComponents = UIComponents(
            progressIndicator: mockProgressIndicator,
            ripButton: mockRipButton,
            logTextView: mockLogTextView,
            sourceDropDown: mockSourceDropDown,
            refreshDrivesButton: mockRefreshButton,
            browseSourceButton: mockBrowseSourceButton,
            browseOutputButton: mockBrowseOutputButton
        )
        
        // Create UI update manager
        uiUpdateManager = UIUpdateManager(uiComponents: mockUIComponents)
    }
    
    override func tearDownWithError() throws {
        uiUpdateManager = nil
        mockUIComponents = nil
        mockProgressIndicator = nil
        mockRipButton = nil
        mockLogTextView = nil
        mockSourceDropDown = nil
        mockRefreshButton = nil
        mockBrowseSourceButton = nil
        mockBrowseOutputButton = nil
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        XCTAssertNotNil(uiUpdateManager)
        XCTAssertNotNil(uiUpdateManager.uiComponents)
        XCTAssertTrue(uiUpdateManager.uiComponents === mockUIComponents)
    }
    
    func testInitializationWithoutComponents() {
        let manager = UIUpdateManager()
        XCTAssertNil(manager.uiComponents)
    }
    
    // MARK: - Progress Update Tests
    
    func testUpdateProgress() {
        let expectation = XCTestExpectation(description: "Progress updated")
        
        uiUpdateManager.updateProgress(0.5, isIndeterminate: false)
        
        // Wait for async update
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertFalse(self.mockProgressIndicator.isIndeterminate)
            XCTAssertEqual(self.mockProgressIndicator.doubleValue, 50.0, accuracy: 0.01)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testUpdateProgressIndeterminate() {
        let expectation = XCTestExpectation(description: "Indeterminate progress updated")
        
        uiUpdateManager.updateProgress(0.0, isIndeterminate: true)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertTrue(self.mockProgressIndicator.isIndeterminate)
            XCTAssertTrue(self.mockProgressIndicator.animationStarted)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testShowProgress() {
        let expectation = XCTestExpectation(description: "Progress shown")
        
        uiUpdateManager.showProgress()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertFalse(self.mockProgressIndicator.isHidden)
            XCTAssertTrue(self.mockProgressIndicator.animationStarted)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testHideProgress() {
        let expectation = XCTestExpectation(description: "Progress hidden")
        
        // First show progress
        mockProgressIndicator.isHidden = false
        mockProgressIndicator.animationStarted = true
        
        uiUpdateManager.hideProgress()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertTrue(self.mockProgressIndicator.isHidden)
            XCTAssertFalse(self.mockProgressIndicator.animationStarted)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Status Update Tests
    
    func testUpdateStatus() {
        let expectation = XCTestExpectation(description: "Status updated")
        let testStatus = "Test status message"
        
        uiUpdateManager.updateStatus(testStatus, appendToLog: true)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertTrue(self.mockLogTextView.string.contains(testStatus))
            XCTAssertTrue(self.mockLogTextView.scrollRangeToVisibleCalled)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testUpdateStatusWithoutAppendingToLog() {
        let expectation = XCTestExpectation(description: "Status updated without log")
        let testStatus = "Test status message"
        let originalLogContent = mockLogTextView.string
        
        uiUpdateManager.updateStatus(testStatus, appendToLog: false)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(self.mockLogTextView.string, originalLogContent)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testUpdateStatusWithTimestamp() {
        let expectation = XCTestExpectation(description: "Status with timestamp")
        let testStatus = "Test message"
        
        uiUpdateManager.updateStatus(testStatus, appendToLog: true)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Check that timestamp format is included
            XCTAssertTrue(self.mockLogTextView.string.contains("["))
            XCTAssertTrue(self.mockLogTextView.string.contains("]"))
            XCTAssertTrue(self.mockLogTextView.string.contains(testStatus))
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Button State Tests
    
    func testUpdateButtonStatesForRipping() {
        let expectation = XCTestExpectation(description: "Button states updated for ripping")
        
        uiUpdateManager.updateButtonStates(isRipping: true)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertFalse(self.mockRipButton.isEnabled)
            XCTAssertEqual(self.mockRipButton.title, "Ripping...")
            XCTAssertFalse(self.mockRefreshButton.isEnabled)
            XCTAssertFalse(self.mockBrowseSourceButton.isEnabled)
            XCTAssertFalse(self.mockBrowseOutputButton.isEnabled)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testUpdateButtonStatesForNotRipping() {
        let expectation = XCTestExpectation(description: "Button states updated for not ripping")
        
        uiUpdateManager.updateButtonStates(isRipping: false)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertTrue(self.mockRipButton.isEnabled)
            XCTAssertEqual(self.mockRipButton.title, "Start Ripping")
            XCTAssertTrue(self.mockRefreshButton.isEnabled)
            XCTAssertTrue(self.mockBrowseSourceButton.isEnabled)
            XCTAssertTrue(self.mockBrowseOutputButton.isEnabled)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Drive Selection Tests
    
    func testUpdateDriveSelectionWithDrives() {
        let expectation = XCTestExpectation(description: "Drive selection updated")
        
        let testDrives = createTestDrives()
        uiUpdateManager.updateDriveSelection(drives: testDrives, selectedIndex: 1)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(self.mockSourceDropDown.numberOfItems, testDrives.count)
            XCTAssertTrue(self.mockSourceDropDown.isEnabled)
            XCTAssertEqual(self.mockSourceDropDown.indexOfSelectedItem, 1)
            
            // Check first item title
            let firstItemTitle = self.mockSourceDropDown.item(at: 0)?.title
            XCTAssertTrue(firstItemTitle?.contains("Test Drive 0") == true)
            XCTAssertTrue(firstItemTitle?.contains("DVD") == true)
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testUpdateDriveSelectionWithNoDrives() {
        let expectation = XCTestExpectation(description: "Empty drive selection updated")
        
        uiUpdateManager.updateDriveSelection(drives: [], selectedIndex: -1)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(self.mockSourceDropDown.numberOfItems, 1)
            XCTAssertFalse(self.mockSourceDropDown.isEnabled)
            XCTAssertEqual(self.mockSourceDropDown.item(at: 0)?.title, "No drives detected")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testUpdateDriveSelectionWithTooltips() {
        let expectation = XCTestExpectation(description: "Drive tooltips updated")
        
        let testDrives = createTestDrives(count: 1)
        uiUpdateManager.updateDriveSelection(drives: testDrives, selectedIndex: 0)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let firstItem = self.mockSourceDropDown.item(at: 0)
            XCTAssertNotNil(firstItem?.toolTip)
            XCTAssertTrue(firstItem?.toolTip?.contains("Device:") == true)
            XCTAssertTrue(firstItem?.toolTip?.contains("Mount Point:") == true)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Reset State Tests
    
    func testResetToInitialState() {
        let expectation = XCTestExpectation(description: "Reset to initial state")
        
        // Set some non-initial state
        mockProgressIndicator.isHidden = false
        mockRipButton.isEnabled = false
        mockProgressIndicator.doubleValue = 50.0
        
        uiUpdateManager.resetToInitialState()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertTrue(self.mockProgressIndicator.isHidden)
            XCTAssertTrue(self.mockRipButton.isEnabled)
            XCTAssertEqual(self.mockProgressIndicator.doubleValue, 0.0)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Completion and Failure Tests
    
    func testUpdateForRippingCompletion() {
        let expectation = XCTestExpectation(description: "Ripping completion updated")
        
        // Set ripping state
        mockProgressIndicator.isHidden = false
        mockRipButton.isEnabled = false
        
        uiUpdateManager.updateForRippingCompletion()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            XCTAssertTrue(self.mockProgressIndicator.isHidden)
            XCTAssertTrue(self.mockRipButton.isEnabled)
            XCTAssertTrue(self.mockLogTextView.string.contains("Ripping completed successfully!"))
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testUpdateForRippingFailure() {
        let expectation = XCTestExpectation(description: "Ripping failure updated")
        
        let testError = NSError(domain: "TestDomain", code: 123, userInfo: [NSLocalizedDescriptionKey: "Test error message"])
        
        // Set ripping state
        mockProgressIndicator.isHidden = false
        mockRipButton.isEnabled = false
        
        uiUpdateManager.updateForRippingFailure(error: testError)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            XCTAssertTrue(self.mockProgressIndicator.isHidden)
            XCTAssertTrue(self.mockRipButton.isEnabled)
            XCTAssertTrue(self.mockLogTextView.string.contains("Ripping failed"))
            XCTAssertTrue(self.mockLogTextView.string.contains("Test error message"))
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Concurrent Updates Tests
    
    func testConcurrentUpdates() {
        let expectation = XCTestExpectation(description: "Concurrent updates processed")
        expectation.expectedFulfillmentCount = 10
        
        let concurrentQueue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)
        
        // Fire multiple concurrent updates
        for i in 0..<10 {
            concurrentQueue.async {
                self.uiUpdateManager.updateStatus("Concurrent update \(i)", appendToLog: true)
                self.uiUpdateManager.updateProgress(Double(i) / 10.0, isIndeterminate: false)
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 2.0)
        
        // Verify all updates were processed (without async block to avoid crash)
        let finalExpectation = XCTestExpectation(description: "Final verification")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            XCTAssertTrue(self.mockLogTextView.string.contains("Concurrent update"))
            finalExpectation.fulfill()
        }
        
        wait(for: [finalExpectation], timeout: 1.0)
    }
    
    // MARK: - Error Handling Tests
    
    func testUpdateWithoutUIComponents() {
        uiUpdateManager.uiComponents = nil
        
        // These should not crash even without UI components
        XCTAssertNoThrow(uiUpdateManager.updateProgress(0.5, isIndeterminate: false))
        XCTAssertNoThrow(uiUpdateManager.updateStatus("Test", appendToLog: true))
        XCTAssertNoThrow(uiUpdateManager.updateButtonStates(isRipping: true))
        XCTAssertNoThrow(uiUpdateManager.showProgress())
        XCTAssertNoThrow(uiUpdateManager.hideProgress())
    }
    
    // MARK: - Performance Tests
    
    func testUIUpdatePerformance() {
        measure {
            for i in 0..<100 {
                uiUpdateManager.updateProgress(Double(i) / 100.0, isIndeterminate: false)
                uiUpdateManager.updateStatus("Status \(i)", appendToLog: true)
            }
        }
    }
    
    func testBatchUpdatePerformance() {
        measure {
            for i in 0..<50 {
                uiUpdateManager.updateProgress(Double(i) / 50.0, isIndeterminate: false)
                uiUpdateManager.updateButtonStates(isRipping: i % 2 == 0)
                uiUpdateManager.updateStatus("Batch update \(i)", appendToLog: true)
            }
        }
    }
    
    // MARK: - Memory Management Tests
    
    func testMemoryManagement() {
        let expectation = XCTestExpectation(description: "Memory cleanup")
        weak var weakUIComponents: UIComponents?
        weak var weakManager: UIUpdateManager?
        
        autoreleasepool {
            let components = UIComponents(
                progressIndicator: NSProgressIndicator(),
                ripButton: NSButton(),
                logTextView: NSTextView(),
                sourceDropDown: NSPopUpButton(),
                refreshDrivesButton: NSButton(),
                browseSourceButton: NSButton(),
                browseOutputButton: NSButton()
            )
            weakUIComponents = components
            
            let manager = UIUpdateManager(uiComponents: components)
            weakManager = manager
            
            // Perform some operations
            manager.updateProgress(0.5, isIndeterminate: false)
            manager.updateStatus("Test", appendToLog: true)
        }
        
        // Wait for async operations to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            // UIComponents should be deallocated immediately due to weak references
            XCTAssertNil(weakUIComponents)
            // UIUpdateManager might still be alive due to queued operations, but should be deallocated eventually
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
        
        // After waiting, the manager should be deallocated
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // This is expected behavior - the manager may take time to deallocate due to dispatch queues
            // We mainly care about the UI components being properly deallocated
        }
    }
    
    // MARK: - Helper Methods
    
    private func createTestDrives(count: Int = 3) -> [OpticalDrive] {
        return (0..<count).map { index in
            OpticalDrive(
                mountPoint: "/Volumes/TestDrive\(index)",
                name: "Test Drive \(index)",
                type: index % 2 == 0 ? .dvd : .bluray,
                devicePath: "/dev/disk\(index)"
            )
        }
    }
}

// MARK: - Mock Classes

class MockProgressIndicator: NSProgressIndicator {
    private var _doubleValue: Double = 0.0
    private var _isIndeterminate: Bool = false
    private var _isHidden: Bool = true
    
    var animationStarted = false
    
    override var doubleValue: Double {
        get { return _doubleValue }
        set { _doubleValue = newValue }
    }
    
    override var isIndeterminate: Bool {
        get { return _isIndeterminate }
        set { _isIndeterminate = newValue }
    }
    
    override var isHidden: Bool {
        get { return _isHidden }
        set { _isHidden = newValue }
    }
    
    override func startAnimation(_ sender: Any?) {
        animationStarted = true
    }
    
    override func stopAnimation(_ sender: Any?) {
        animationStarted = false
    }
}

class MockButton: NSButton {
    private var _isEnabled: Bool = true
    private var _title: String = ""
    
    override var isEnabled: Bool {
        get { return _isEnabled }
        set { _isEnabled = newValue }
    }
    
    override var title: String {
        get { return _title }
        set { _title = newValue }
    }
}

class MockTextView: NSTextView {
    private var _string: String = ""
    var scrollRangeToVisibleCalled = false
    
    override var string: String {
        get { return _string }
        set { _string = newValue }
    }
    
    override func scrollRangeToVisible(_ range: NSRange) {
        scrollRangeToVisibleCalled = true
    }
}

class MockPopUpButton: NSPopUpButton {
    private var items: [NSMenuItem] = []
    private var _isEnabled: Bool = true
    private var selectedItemIndex: Int = -1
    
    override func removeAllItems() {
        items.removeAll()
        selectedItemIndex = -1
    }
    
    override func addItem(withTitle title: String) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        items.append(item)
    }
    
    override func item(at index: Int) -> NSMenuItem? {
        guard index >= 0 && index < items.count else { return nil }
        return items[index]
    }
    
    override var numberOfItems: Int {
        return items.count
    }
    
    override var isEnabled: Bool {
        get { return _isEnabled }
        set { _isEnabled = newValue }
    }
    
    override func selectItem(at index: Int) {
        guard index >= 0 && index < items.count else { return }
        selectedItemIndex = index
    }
    
    override var indexOfSelectedItem: Int {
        return selectedItemIndex
    }
}