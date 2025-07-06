import Cocoa
import UserNotifications

// MARK: - Utility Functions

extension MainViewController {
    
    func appendToLog(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let logMessage = "[\(timestamp)] \(message)\n"
        
        logTextView.textStorage?.append(NSAttributedString(string: logMessage))
        logTextView.scrollToEndOfDocument(self)
    }
    
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
            installProcess.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
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
    
    private func ejectDisk(at devicePath: String) -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/diskutil")
        task.arguments = ["eject", devicePath]
        
        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
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
        
        // If no drives are detected, return nil
        if detectedDrives.isEmpty {
            return nil
        }
        
        if selectedIndex >= 0 && selectedIndex < detectedDrives.count {
            return detectedDrives[selectedIndex].mountPoint
        }
        
        // Check if it's a custom path
        if let selectedTitle = sourceDropDown.titleOfSelectedItem,
           selectedTitle.hasPrefix("Custom: ") {
            // Extract path from custom entry - this is a simplified approach
            // In a real implementation, you'd want to store the actual path
            return settingsManager.lastSourcePath
        }
        
        return nil
    }
    
    func loadSettings() {
        // Load output path
        if let lastOutputPath = settingsManager.lastOutputPath {
            outputPathField.stringValue = lastOutputPath
        }
        
        // Load automation settings
        autoRipCheckbox.state = settingsManager.autoRipEnabled ? .on : .off
        autoEjectCheckbox.state = settingsManager.autoEjectEnabled ? .on : .off
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
            print("[AutoRip2MKV] Skipping completion notification in test environment")
            return
        }
        
        // Additional safety check for notification center availability
        guard Bundle.main.bundleIdentifier != nil else {
            print("[AutoRip2MKV] No valid bundle identifier, skipping notification")
            return
        }
        
        if #available(macOS 10.14, *) {
            let content = UNMutableNotificationContent()
            content.title = "AutoRip2MKV"
            content.body = "Disc ripping completed successfully!"
            content.sound = UNNotificationSound.default
            
            let request = UNNotificationRequest(
                identifier: "rip-completion", 
                content: content, 
                trigger: nil
            )
            
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("[AutoRip2MKV] Failed to show notification: \(error)")
                }
            }
        } else {
            // Fallback for older macOS versions
            let notification = NSUserNotification()
            notification.title = "AutoRip2MKV"
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
            print("[AutoRip2MKV] Skipping error notification in test environment: \(message)")
            return
        }
        
        // Additional safety check for notification center availability
        guard Bundle.main.bundleIdentifier != nil else {
            print("[AutoRip2MKV] No valid bundle identifier, skipping error notification")
            return
        }
        
        if #available(macOS 10.14, *) {
            let content = UNMutableNotificationContent()
            content.title = "AutoRip2MKV - Error"
            content.body = message
            content.sound = UNNotificationSound.default
            
            let request = UNNotificationRequest(
                identifier: "rip-error", 
                content: content, 
                trigger: nil
            )
            
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("[AutoRip2MKV] Failed to show error notification: \(error)")
                }
            }
        } else {
            // Fallback for older macOS versions
            let notification = NSUserNotification()
            notification.title = "AutoRip2MKV - Error"
            notification.informativeText = message
            notification.soundName = NSUserNotificationDefaultSoundName
            NSUserNotificationCenter.default.deliver(notification)
        }
    }
}
