import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {

    var window: NSWindow!
    var mainViewController: MainViewController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create the main window
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "AutoRip2MKV for Mac"
        window.center()

        // Create and set up the main view controller
        mainViewController = MainViewController()
        window.contentViewController = mainViewController

        // Make the window visible
        window.makeKeyAndOrderFront(nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
