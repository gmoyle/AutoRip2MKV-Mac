import Cocoa

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
    
    func getFFmpegExecutablePath() -> String? {
        // First try bundled FFmpeg
        if let bundledPath = getBundledFFmpegPath(), FileManager.default.fileExists(atPath: bundledPath) {
            return bundledPath
        }
        
        // Then try system PATH
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["ffmpeg"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !path.isEmpty {
                    return path
                }
            }
        } catch {
            appendToLog("Error checking for FFmpeg: \(error.localizedDescription)")
        }
        
        return nil
    }
    
    func getBundledFFmpegPath() -> String? {
        let bundlePath = Bundle.main.bundlePath
        let ffmpegPath = bundlePath.appending("/Contents/Resources/ffmpeg")
        return ffmpegPath
    }
    
    func installFFmpegIfNeeded() {
        guard !isFFmpegAvailable() else {
            appendToLog("FFmpeg is available")
            return
        }
        
        appendToLog("FFmpeg not found. Attempting to install via Homebrew...")
        
        // Check if Homebrew is available
        let homebrewCheck = Process()
        homebrewCheck.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        homebrewCheck.arguments = ["brew"]
        
        do {
            try homebrewCheck.run()
            homebrewCheck.waitUntilExit()
            
            if homebrewCheck.terminationStatus == 0 {
                installFFmpegWithHomebrew()
            } else {
                appendToLog("Homebrew not found. Please install FFmpeg manually.")
                showAlert(title: "FFmpeg Required", 
                         message: "FFmpeg is required for video conversion. Please install it manually or via Homebrew."
                )
            }
        } catch {
            appendToLog("Error checking for Homebrew: \(error.localizedDescription)")
        }
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
        let notification = NSUserNotification()
        notification.title = "AutoRip2MKV"
        notification.informativeText = "Disc ripping completed successfully!"
        notification.soundName = NSUserNotificationDefaultSoundName
        
        NSUserNotificationCenter.default.deliver(notification)
    }
    
    func showErrorNotification(_ message: String) {
        let notification = NSUserNotification()
        notification.title = "AutoRip2MKV - Error"
        notification.informativeText = message
        notification.soundName = NSUserNotificationDefaultSoundName
        
        NSUserNotificationCenter.default.deliver(notification)
    }
}
