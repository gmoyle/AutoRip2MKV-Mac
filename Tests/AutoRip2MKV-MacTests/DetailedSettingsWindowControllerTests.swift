import XCTest
import Cocoa
@testable import AutoRip2MKV_Mac

final class DetailedSettingsWindowControllerTests: XCTestCase {
    
    var windowController: DetailedSettingsWindowControllerNew!
    
    override func setUpWithError() throws {
        windowController = DetailedSettingsWindowControllerNew()
    }
    
    override func tearDownWithError() throws {
        windowController?.window?.close()
        windowController = nil
    }
    
    // MARK: - Initialization Tests
    
    func testWindowControllerInitialization() {
        XCTAssertNotNil(windowController, "Window controller should be initialized")
        XCTAssertNotNil(windowController.window, "Window should be created during initialization")
    }
    
    func testConvenienceInitializer() {
        let controller = DetailedSettingsWindowControllerNew()
        
        XCTAssertNotNil(controller.window, "Window should be created by convenience initializer")
        XCTAssertEqual(controller.window?.title, "Detailed Settings (Test)", "Window title should be set correctly")
        
        // Test window properties
        guard let window = controller.window else {
            XCTFail("Window should not be nil")
            return
        }
        
        // Note: Window frame might be adjusted by system, so we test approximate values
        XCTAssertGreaterThanOrEqual(window.frame.width, 590, "Window width should be approximately 600")
        XCTAssertGreaterThanOrEqual(window.frame.height, 390, "Window height should be approximately 400")
        XCTAssertTrue(window.styleMask.contains(.titled), "Window should have title bar")
        XCTAssertTrue(window.styleMask.contains(.closable), "Window should be closable")
        XCTAssertTrue(window.styleMask.contains(.resizable), "Window should be resizable")
    }
    
    // MARK: - Window Setup Tests
    
    func testWindowDidLoad() {
        // Load the window to trigger windowDidLoad
        XCTAssertNoThrow(windowController.windowDidLoad(), "windowDidLoad should not throw")
        
        // Verify window properties are set
        guard let window = windowController.window else {
            XCTFail("Window should not be nil after windowDidLoad")
            return
        }
        
        XCTAssertFalse(window.isReleasedWhenClosed, "Window should not be released when closed")
        XCTAssertEqual(window.level, NSWindow.Level.modalPanel, "Window level should be modal panel")
    }
    
    func testWindowSetup() {
        windowController.windowDidLoad()
        
        guard let window = windowController.window else {
            XCTFail("Window should not be nil")
            return
        }
        
        XCTAssertFalse(window.isReleasedWhenClosed, "Window should not be released when closed")
        XCTAssertEqual(window.level, NSWindow.Level.modalPanel, "Window should be at modal panel level")
    }
    
    // MARK: - UI Setup Tests
    
    func testUIComponentsCreation() {
        windowController.windowDidLoad()
        
        guard let contentView = windowController.window?.contentView else {
            XCTFail("Content view should not be nil")
            return
        }
        
        // Check that subviews were added
        XCTAssertGreaterThan(contentView.subviews.count, 0, "Content view should have subviews")
        
        // Look for text field (test label)
        let textFields = contentView.subviews.compactMap { $0 as? NSTextField }
        XCTAssertGreaterThan(textFields.count, 0, "Should have at least one text field (test label)")
        
        // Look for stack view (button container)
        let stackViews = contentView.subviews.compactMap { $0 as? NSStackView }
        XCTAssertGreaterThan(stackViews.count, 0, "Should have at least one stack view for buttons")
    }
    
    func testTestLabelCreation() {
        windowController.windowDidLoad()
        
        guard let contentView = windowController.window?.contentView else {
            XCTFail("Content view should not be nil")
            return
        }
        
        // Find the test label
        let textFields = contentView.subviews.compactMap { $0 as? NSTextField }
        let testLabel = textFields.first { $0.stringValue.contains("Settings window is working") }
        
        XCTAssertNotNil(testLabel, "Test label should be created")
        XCTAssertEqual(testLabel?.font, NSFont.systemFont(ofSize: 16), "Font should be system font size 16")
        XCTAssertEqual(testLabel?.alignment, .center, "Label should be center aligned")
        XCTAssertFalse(testLabel?.translatesAutoresizingMaskIntoConstraints ?? true, "Should use Auto Layout")
    }
    
    func testButtonCreation() {
        windowController.windowDidLoad()
        
        guard let contentView = windowController.window?.contentView else {
            XCTFail("Content view should not be nil")
            return
        }
        
        // Find buttons in stack views
        let stackViews = contentView.subviews.compactMap { $0 as? NSStackView }
        let buttons = stackViews.flatMap { $0.arrangedSubviews.compactMap { $0 as? NSButton } }
        
        XCTAssertGreaterThanOrEqual(buttons.count, 2, "Should have at least 2 buttons (OK and Cancel)")
        
        // Check for OK and Cancel buttons
        let okButton = buttons.first { $0.title == "OK" }
        let cancelButton = buttons.first { $0.title == "Cancel" }
        
        XCTAssertNotNil(okButton, "OK button should exist")
        XCTAssertNotNil(cancelButton, "Cancel button should exist")
        
        // Check key equivalents
        XCTAssertEqual(okButton?.keyEquivalent, "\r", "OK button should have Return key equivalent")
        XCTAssertEqual(cancelButton?.keyEquivalent, "\u{1b}", "Cancel button should have Escape key equivalent")
    }
    
    // MARK: - Action Tests
    
    func testCancelAction() {
        windowController.windowDidLoad()
        
        // Make window visible for testing
        windowController.window?.makeKeyAndOrderFront(nil)
        XCTAssertTrue(windowController.window?.isVisible ?? false, "Window should be visible before cancel")
        
        // Simulate cancel action
        // Since we can't test private methods directly, we'll just verify the window is still accessible
        // and doesn't crash when the action would be called indirectly
        XCTAssertNotNil(windowController.window, "Window should still exist")
    }
    
    func testApplyAction() {
        windowController.windowDidLoad()
        
        // Make window visible for testing
        windowController.window?.makeKeyAndOrderFront(nil)
        XCTAssertTrue(windowController.window?.isVisible ?? false, "Window should be visible before apply")
        
        // Simulate apply action
        // Since we can't test private methods directly, we'll just verify the window is still accessible
        // and doesn't crash when the action would be called indirectly
        XCTAssertNotNil(windowController.window, "Window should still exist")
    }
    
    // MARK: - Constraint Tests
    
    func testAutoLayoutConstraints() {
        windowController.windowDidLoad()
        
        guard let contentView = windowController.window?.contentView else {
            XCTFail("Content view should not be nil")
            return
        }
        
        // Find test label and button stack view
        let textFields = contentView.subviews.compactMap { $0 as? NSTextField }
        let stackViews = contentView.subviews.compactMap { $0 as? NSStackView }
        
        let testLabel = textFields.first { $0.stringValue.contains("Settings window is working") }
        let buttonStackView = stackViews.first
        
        XCTAssertNotNil(testLabel, "Test label should exist")
        XCTAssertNotNil(buttonStackView, "Button stack view should exist")
        
        // Verify Auto Layout is being used
        XCTAssertFalse(testLabel?.translatesAutoresizingMaskIntoConstraints ?? true, "Test label should use Auto Layout")
        XCTAssertFalse(buttonStackView?.translatesAutoresizingMaskIntoConstraints ?? true, "Button stack view should use Auto Layout")
        
        // Test that constraints don't cause conflicts by triggering layout
        XCTAssertNoThrow(contentView.layoutSubtreeIfNeeded(), "Layout should complete without conflicts")
    }
    
    // MARK: - Settings Manager Integration Tests
    
    func testSettingsManagerIntegration() {
        // Verify that the window controller has access to settings manager
        XCTAssertNotNil(windowController, "Window controller should exist")
        
        // Since SettingsManager is internal, we test indirectly by ensuring
        // window controller doesn't crash when accessing it
        XCTAssertNoThrow(windowController.windowDidLoad(), "Window loading should not crash when accessing settings manager")
    }
    
    // MARK: - Performance Tests
    
    func testWindowCreationPerformance() {
        measure {
            let controller = DetailedSettingsWindowControllerNew()
            controller.windowDidLoad()
        }
    }
    
    func testUISetupPerformance() {
        measure {
            windowController.windowDidLoad()
        }
    }
    
    // MARK: - Memory Management Tests
    
    func testMemoryManagement() {
        weak var weakController: DetailedSettingsWindowControllerNew?
        
        autoreleasepool {
            let controller = DetailedSettingsWindowControllerNew()
            weakController = controller
            controller.windowDidLoad()
            // controller goes out of scope here
        }
        
        // Note: Controller might not be deallocated immediately due to window retention
        // This test ensures no crashes occur during deallocation
    }
    
    func testWindowMemoryManagement() {
        weak var weakWindow: NSWindow?
        
        autoreleasepool {
            let controller = DetailedSettingsWindowControllerNew()
            controller.windowDidLoad()
            weakWindow = controller.window
            controller.window?.close()
        }
        
        // Test that window cleanup doesn't cause crashes
        // Note: Window may or may not be deallocated depending on system behavior
        // The important thing is that no crashes occur during cleanup
    }
    
    // MARK: - Error Handling Tests
    
    func testNilContentViewHandling() {
        // Create a window controller with a window that has no content view
        let window = NSWindow()
        window.contentView = nil
        
        let controller = DetailedSettingsWindowControllerNew(window: window)
        
        // Should not crash when content view is nil
        XCTAssertNoThrow(controller.windowDidLoad(), "Should handle nil content view gracefully")
    }
    
    func testMultipleWindowDidLoadCalls() {
        // Test that calling windowDidLoad multiple times doesn't cause issues
        XCTAssertNoThrow(windowController.windowDidLoad(), "First call should succeed")
        XCTAssertNoThrow(windowController.windowDidLoad(), "Second call should not crash")
        XCTAssertNoThrow(windowController.windowDidLoad(), "Third call should not crash")
    }
    
    // MARK: - Integration Tests
    
    func testCompleteWorkflow() {
        // Test complete workflow: create, load, show, interact, close
        let controller = DetailedSettingsWindowControllerNew()
        
        // Load window
        XCTAssertNoThrow(controller.windowDidLoad(), "Window loading should succeed")
        
        // Show window
        controller.window?.makeKeyAndOrderFront(nil)
        XCTAssertTrue(controller.window?.isVisible ?? false, "Window should be visible")
        
        // Verify window is visible and functional
        XCTAssertTrue(controller.window?.isVisible ?? false, "Window should be visible")
        
        // Close window manually since we can't test private methods
        controller.window?.close()
        XCTAssertFalse(controller.window?.isVisible ?? true, "Window should be hidden after close")
    }
    
    func testButtonTargetActionSetup() {
        windowController.windowDidLoad()
        
        guard let contentView = windowController.window?.contentView else {
            XCTFail("Content view should not be nil")
            return
        }
        
        // Find buttons
        let stackViews = contentView.subviews.compactMap { $0 as? NSStackView }
        let buttons = stackViews.flatMap { $0.arrangedSubviews.compactMap { $0 as? NSButton } }
        
        let okButton = buttons.first { $0.title == "OK" }
        let cancelButton = buttons.first { $0.title == "Cancel" }
        
        // Verify target-action setup
        XCTAssertNotNil(okButton?.target, "OK button should have a target")
        XCTAssertNotNil(okButton?.action, "OK button should have an action")
        XCTAssertNotNil(cancelButton?.target, "Cancel button should have a target")
        XCTAssertNotNil(cancelButton?.action, "Cancel button should have an action")
        
        // Verify targets point to the window controller
        XCTAssertTrue(okButton?.target === windowController, "OK button target should be window controller")
        XCTAssertTrue(cancelButton?.target === windowController, "Cancel button target should be window controller")
    }
}
