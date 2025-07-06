import Foundation
import Cocoa

/// Utility class for handling test environment detection and dialog management
class TestingUtilities {

    /// Singleton instance
    static let shared = TestingUtilities()

    private init() {}

    /// Detects if the application is running in a test environment
    /// This includes unit tests, UI tests, and headless mode
    var isRunningInTestEnvironment: Bool {
        // Check for XCTest framework presence
        if NSClassFromString("XCTestCase") != nil {
            return true
        }

        // Check for XCTest configuration file path (used during testing)
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return true
        }

        // Check if the main bundle is the XCTest bundle (more reliable for CI)
        if let bundleIdentifier = Bundle.main.bundleIdentifier,
           bundleIdentifier.contains("xctest") {
            return true
        }

        // Check for test bundle path patterns
        let mainBundlePath = Bundle.main.bundlePath
        if mainBundlePath.contains(".xctest") || mainBundlePath.contains("xctest") {
            return true
        }

        // Check for command line arguments that indicate testing/headless mode
        let arguments = CommandLine.arguments + ProcessInfo.processInfo.arguments
        if arguments.contains("--headless") ||
           arguments.contains("--testing") ||
           arguments.contains("--ci") ||
           arguments.contains("--automated") {
            return true
        }

        // Check environment variables that might indicate test/CI environment
        let environment = ProcessInfo.processInfo.environment
        if environment["CI"] != nil ||
           environment["GITHUB_ACTIONS"] != nil ||
           environment["JENKINS_URL"] != nil ||
           environment["TESTING"] != nil ||
           environment["HEADLESS"] != nil {
            return true
        }

        return false
    }

    /// Shows an alert with automatic timeout in test environments
    /// - Parameters:
    ///   - title: The alert title
    ///   - message: The alert message
    ///   - style: The alert style (default: .warning)
    ///   - timeout: Timeout in seconds for test environments (default: 0.5)
    ///   - logHandler: Optional closure to handle logging instead of showing alert
    func showAlert(title: String,
                  message: String,
                  style: NSAlert.Style = .warning,
                  timeout: TimeInterval = 0.5,
                  logHandler: ((String, String) -> Void)? = nil) {

        if isRunningInTestEnvironment {
            // In test environment, use log handler if provided, otherwise just log to console
            if let logHandler = logHandler {
                logHandler(title, message)
            } else {
                print("ALERT [\(alertStyleString(style))]: \(title) - \(message)")
            }
            return
        }

        // In normal environment, show the alert
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = style
        alert.runModal()
    }

    /// Shows a file panel with automatic simulation in test environments
    /// - Parameters:
    ///   - panel: The configured NSOpenPanel or NSSavePanel
    ///   - testPath: The simulated path to return in test environments
    ///   - logHandler: Optional closure to handle logging
    /// - Returns: The selected URL or nil
    func showFilePanel(_ panel: NSOpenPanel,
                      testPath: String? = nil,
                      logHandler: ((String) -> Void)? = nil) -> URL? {

        if isRunningInTestEnvironment {
            let simulatedPath = testPath ?? "/tmp/test_path"
            if let logHandler = logHandler {
                logHandler("TEST: Simulating file panel selection: \(simulatedPath)")
            } else {
                print("TEST: Simulating file panel selection: \(simulatedPath)")
            }
            return URL(fileURLWithPath: simulatedPath)
        }

        // In normal environment, show the actual panel
        if panel.runModal() == .OK {
            return panel.url
        }

        return nil
    }

    /// Helper method to get string representation of alert style
    private func alertStyleString(_ style: NSAlert.Style) -> String {
        switch style {
        case .warning:
            return "WARNING"
        case .informational:
            return "INFO"
        case .critical:
            return "CRITICAL"
        @unknown default:
            return "UNKNOWN"
        }
    }
}

/// Extension to make testing utilities easily accessible
extension NSViewController {

    /// Convenience property to access testing utilities
    var testingUtils: TestingUtilities {
        return TestingUtilities.shared
    }

    /// Convenience method to check if running in test environment
    var isRunningInTestEnvironment: Bool {
        return TestingUtilities.shared.isRunningInTestEnvironment
    }
}
