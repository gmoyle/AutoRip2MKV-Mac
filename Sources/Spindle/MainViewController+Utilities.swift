import Cocoa
import UserNotifications

// MARK: - Utility Functions

extension MainViewController {

    func appendToLog(_ message: String) {
        // Touches an NSTextView (AppKit layout), so it must run on the main
        // thread. Callers include background contexts — URLSession completions,
        // ripper delegate callbacks — so marshal here rather than at every call
        // site. Off-main UI mutation aborts the AppKit layout engine (SIGABRT).
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.appendToLog(message) }
            return
        }
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let logMessage = "[\(timestamp)] \(message)\n"

        // An attributed string with no attributes draws black in a default font,
        // which is invisible in Dark Mode. labelColor follows the appearance.
        let attributes: [NSAttributedString.Key: Any] = [
            .font: Self.logFont,
            .foregroundColor: NSColor.labelColor
        ]
        logTextView.textStorage?.append(NSAttributedString(string: logMessage, attributes: attributes))
        logTextView.scrollToEndOfDocument(self)
    }

    static let logFont = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)

    func showAlert(title: String, message: String) {
        testingUtils.showAlert(title: title, message: message) { [weak self] alertTitle, alertMessage in
            self?.appendToLog("ALERT: \(alertTitle) - \(alertMessage)")
        }
    }

    // MARK: - FFmpeg Detection and Installation

    func isFFmpegAvailable() -> Bool {
        // First check if bundled FFmpeg exists
        if let bundledPath = getBundledFFmpegPath(), FileManager.default.fileExists(atPath: bundledPath) {
            return true
        }

        // Then check system PATH
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["ffmpeg"]

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    func installFFmpegIfNeeded() {
        // Use the new comprehensive FFmpeg availability check and installation
        ensureFFmpegAvailable()
    }

    private func installFFmpegWithHomebrew() {
        let installProcess = Process()
        installProcess.executableURL = URL(fileURLWithPath: "/usr/local/bin/brew")
        installProcess.arguments = ["install", "ffmpeg"]

        let pipe = Pipe()
        installProcess.standardOutput = pipe
        installProcess.standardError = pipe

        do {
            appendToLog("Installing FFmpeg via Homebrew...")
            try installProcess.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()  // drain before waiting: a full pipe blocks the child
            installProcess.waitUntilExit()

            if let output = String(data: data, encoding: .utf8) {
                appendToLog("Homebrew output: \(output)")
            }

            if installProcess.terminationStatus == 0 {
                appendToLog("FFmpeg installed successfully")
            } else {
                appendToLog("Failed to install FFmpeg via Homebrew")
                showAlert(title: "Installation Failed",
                         message: "Failed to install FFmpeg automatically. Please install it manually.")
            }
        } catch {
            appendToLog("Error installing FFmpeg: \(error.localizedDescription)")
        }
    }

    // MARK: - Disk Management

    /// Default rip destination: the local Plex movie library when one exists,
    /// otherwise ~/Movies/Spindle.
    private func defaultOutputDirectory() -> String {
        if let plexPath = plexMovieLibraryPath() {
            appendToLog("Plex movie library detected — defaulting output to \(plexPath)")
            return plexPath
        }
        let fallback = NSString(string: "~/Movies/Spindle").expandingTildeInPath
        try? FileManager.default.createDirectory(
            atPath: fallback, withIntermediateDirectories: true)
        return fallback
    }

    /// First writable movie-library folder from a local Plex Media Server install.
    private func plexMovieLibraryPath() -> String? {
        let db = NSString(string: "~/Library/Application Support/Plex Media Server"
            + "/Plug-in Support/Databases/com.plexapp.plugins.library.db").expandingTildeInPath
        guard FileManager.default.fileExists(atPath: db) else { return nil }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        // -readonly so a running Plex server's database is never disturbed;
        // section_type 1 is Plex's movie library type
        task.arguments = ["-readonly", db,
                          "SELECT sl.root_path FROM section_locations sl "
                          + "JOIN library_sections ls ON sl.library_section_id = ls.id "
                          + "WHERE ls.section_type = 1 ORDER BY sl.id;"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()  // drain before waiting
            task.waitUntilExit()
            guard task.terminationStatus == 0 else { return nil }
            let output = String(data: data, encoding: .utf8) ?? ""
            for line in output.split(separator: "\n") {
                let path = line.trimmingCharacters(in: .whitespaces)
                var isDirectory: ObjCBool = false
                if !path.isEmpty,
                   FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory),
                   isDirectory.boolValue,
                   FileManager.default.isWritableFile(atPath: path) {
                    return path
                }
            }
        } catch {
            return nil
        }
        return nil
    }

    func ejectCurrentDisk() {
        guard let selectedDrive = getSelectedDrive() else {
            appendToLog("No drive selected for ejection")
            return
        }

        appendToLog("Ejecting disk from \(selectedDrive.name)...")

        DispatchQueue.global(qos: .background).async {
            let result = self.ejectDisk(at: selectedDrive.devicePath)

            DispatchQueue.main.async {
                if result {
                    self.appendToLog("Disk ejected successfully")
                } else {
                    self.appendToLog("Failed to eject disk")
                }
            }
        }
    }

    func ejectDisk(at devicePath: String) -> Bool {
        // Only ever eject removable/optical media — a wrong device path must not
        // unmount an internal or system disk.
        guard isEjectableDevice(devicePath) else {
            Logger.shared.log("Refusing to eject non-removable device \(devicePath)",
                              level: .error, category: .general)
            return false
        }
        // Unmount first so the physical eject isn't blocked by the mounted volume
        _ = runEjectTool("/usr/sbin/diskutil", ["unmountDisk", devicePath])
        let ejected = runEjectTool("/usr/sbin/diskutil", ["eject", devicePath])
        // diskutil eject sometimes only unmounts optical media without opening the
        // tray. drutil can force the physical eject, but it addresses drives by
        // index, not device — so only use it when a single drive makes that unambiguous.
        if ejected, !devicePath.hasPrefix("/dev/") || !FileManager.default.fileExists(atPath: devicePath) {
            return true
        }
        if opticalDriveCount() == 1, runEjectTool("/usr/bin/drutil", ["eject"]) {
            return true
        }
        return ejected
    }

    /// True if diskutil reports `device` (a /dev node or mount point) as
    /// ejectable/removable or optical media.
    private func isEjectableDevice(_ device: String) -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        task.arguments = ["info", "-plist", device]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        guard (try? task.run()) != nil else { return false }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        guard task.terminationStatus == 0,
              let info = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return false }
        if info.keys.contains(where: { $0.hasPrefix("Optical") }) { return true }
        return ["Ejectable", "RemovableMedia", "Removable"].contains { info[$0] as? Bool == true }
    }

    /// Number of optical drives `drutil list` reports (0 if it can't be determined).
    private func opticalDriveCount() -> Int {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/drutil")
        task.arguments = ["list"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        guard (try? task.run()) != nil else { return 0 }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        // Header line, then one line per drive starting with its index.
        let output = String(data: data, encoding: .utf8) ?? ""
        return output.split(separator: "\n").filter {
            $0.trimmingCharacters(in: .whitespaces).first?.isNumber == true
        }.count
    }

    private func runEjectTool(_ toolPath: String, _ arguments: [String]) -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: toolPath)
        task.arguments = arguments
        // Discard output: an unread Pipe can fill and block the tool forever.
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            Logger.shared.log("Eject tool failed to launch: \(toolPath) — \(error.localizedDescription)",
                              level: .error, category: .general)
            return false
        }
    }

    private func getSelectedDrive() -> OpticalDrive? {
        let selectedIndex = sourceDropDown.indexOfSelectedItem

        if selectedIndex >= 0 && selectedIndex < detectedDrives.count {
            return detectedDrives[selectedIndex]
        }

        return nil
    }

    // MARK: - Settings Management

    func getSelectedSourcePath() -> String? {
        let selectedIndex = sourceDropDown.indexOfSelectedItem
        let selectedTitle = sourceDropDown.titleOfSelectedItem
        
        // First check if it's a custom path
        if let title = selectedTitle, title.hasPrefix("Custom: ") {
            return settingsManager.lastSourcePath
        }
        
        // If we have detected drives and a valid selection, use it
        if !detectedDrives.isEmpty && selectedIndex >= 0 && selectedIndex < detectedDrives.count {
            return detectedDrives[selectedIndex].mountPoint
        }
        
        // If no drives are detected but we have a selection, check if it's a valid drive name
        // This handles the case where drives disappear after being selected
        if detectedDrives.isEmpty && selectedIndex >= 0, let title = selectedTitle {
            // Check if this looks like a drive selection (not "No drives detected")
            if !title.contains("No drives detected") {
                // Try to get the path from saved settings as a fallback
                if let lastSourcePath = settingsManager.lastSourcePath {
                    appendToLog("Warning: Selected drive no longer detected, using last known path: \(lastSourcePath)")
                    return lastSourcePath
                }
            }
        }
        
        return nil
    }

    func loadSettings() {
        // Load output path; default so ripping works out of the box
        if let lastOutputPath = settingsManager.lastOutputPath, !lastOutputPath.isEmpty {
            outputPathField.stringValue = lastOutputPath
        } else {
            let defaultDir = defaultOutputDirectory()
            outputPathField.stringValue = defaultDir
            settingsManager.lastOutputPath = defaultDir
        }

        // Load automation settings
        autoRipCheckbox.state = settingsManager.autoRipEnabled ? .on : .off
        autoEjectCheckbox.state = settingsManager.autoEjectEnabled ? .on : .off
        skipRippedCheckbox.state = settingsManager.skipRippedDiscs ? .on : .off
    }

    func saveCurrentSettings() {
        let sourcePath = getSelectedSourcePath()
        let outputPath = outputPathField.stringValue.isEmpty ? nil : outputPathField.stringValue
        let driveIndex = sourceDropDown.indexOfSelectedItem

        settingsManager.saveSettings(
            sourcePath: sourcePath,
            outputPath: outputPath,
            driveIndex: driveIndex
        )
    }

    // MARK: - Notification System

    func showCompletionNotification() {
        // Multiple layers of test environment detection for robustness
        let testEnvironmentDetected = isRunningInTestEnvironment ||
                                     NSClassFromString("XCTestCase") != nil ||
                                     ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
                                     Bundle.main.bundlePath.contains("xctest")

        guard !testEnvironmentDetected else {
            print("[Spindle] Skipping completion notification in test environment")
            return
        }

        // Additional safety check for notification center availability
        guard Bundle.main.bundleIdentifier != nil else {
            print("[Spindle] No valid bundle identifier, skipping notification")
            return
        }

        if #available(macOS 10.14, *) {
            let content = UNMutableNotificationContent()
            content.title = "Spindle"
            content.body = "Disc ripping completed successfully!"
            content.sound = UNNotificationSound.default

            let request = UNNotificationRequest(
                identifier: "rip-completion",
                content: content,
                trigger: nil
            )

            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("[Spindle] Failed to show notification: \(error)")
                }
            }
        } else {
            // Fallback for older macOS versions
            let notification = NSUserNotification()
            notification.title = "Spindle"
            notification.informativeText = "Disc ripping completed successfully!"
            notification.soundName = NSUserNotificationDefaultSoundName
            NSUserNotificationCenter.default.deliver(notification)
        }
    }

    func showErrorNotification(_ message: String) {
        // Multiple layers of test environment detection for robustness
        let testEnvironmentDetected = isRunningInTestEnvironment ||
                                     NSClassFromString("XCTestCase") != nil ||
                                     ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
                                     Bundle.main.bundlePath.contains("xctest")

        guard !testEnvironmentDetected else {
            print("[Spindle] Skipping error notification in test environment: \(message)")
            return
        }

        // Additional safety check for notification center availability
        guard Bundle.main.bundleIdentifier != nil else {
            print("[Spindle] No valid bundle identifier, skipping error notification")
            return
        }

        if #available(macOS 10.14, *) {
            let content = UNMutableNotificationContent()
            content.title = "Spindle - Error"
            content.body = message
            content.sound = UNNotificationSound.default

            let request = UNNotificationRequest(
                identifier: "rip-error",
                content: content,
                trigger: nil
            )

            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("[Spindle] Failed to show error notification: \(error)")
                }
            }
        } else {
            // Fallback for older macOS versions
            let notification = NSUserNotification()
            notification.title = "Spindle - Error"
            notification.informativeText = message
            notification.soundName = NSUserNotificationDefaultSoundName
            NSUserNotificationCenter.default.deliver(notification)
        }
    }
}
