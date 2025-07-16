import Cocoa

// MARK: - FFmpeg Installation

extension MainViewController {

    func getApplicationSupportPath() -> String {
        let fileManager = FileManager.default
        guard let appSupportURL = fileManager.urls(for: .applicationSupportDirectory,
                                                   in: .userDomainMask).first else {
            return NSTemporaryDirectory()
        }

        let appPath = appSupportURL.appendingPathComponent("AutoRip2MKV-Mac")

        // Create directory if it doesn't exist
        if !fileManager.fileExists(atPath: appPath.path) {
            try? fileManager.createDirectory(at: appPath, withIntermediateDirectories: true)
        }

        return appPath.path
    }

    func ensureFFmpegAvailable() {
        // First check if FFmpeg is bundled with the app
        if let bundledPath = getBundledFFmpegPath(), FileManager.default.fileExists(atPath: bundledPath) {
            DispatchQueue.main.async {
                self.appendToLog("Using bundled FFmpeg binary")
                self.appendToLog("FFmpeg is ready for use!")
                self.resetRipButton()
            }
            return
        }

        // Check if already installed in Application Support
        let installedPath = getInstalledFFmpegPath()
        if FileManager.default.fileExists(atPath: installedPath) {
            DispatchQueue.main.async {
                self.appendToLog("Using previously installed FFmpeg")
                self.appendToLog("FFmpeg is ready for use!")
                self.resetRipButton()
            }
            return
        }

        // Check system PATH for FFmpeg
        if isFFmpegAvailable() {
            DispatchQueue.main.async {
                self.appendToLog("Using system FFmpeg installation")
                self.appendToLog("FFmpeg is ready for use!")
                self.resetRipButton()
            }
            return
        }

        // Fall back to downloading
        downloadAndInstallFFmpeg()
    }

    func downloadAndInstallFFmpeg() {
        let architecture = getCurrentArchitecture()
        let downloadURL = getFFmpegDownloadURL(for: architecture)

        DispatchQueue.main.async {
            self.appendToLog("Downloading FFmpeg for \(architecture) architecture...")
        }

        guard let url = URL(string: downloadURL) else {
            DispatchQueue.main.async {
                self.appendToLog("Invalid download URL")
                self.resetRipButton()
            }
            return
        }

        let task = URLSession.shared.downloadTask(with: url) { [weak self] (tempURL, _, error) in
            guard let self = self else { return }

            if let error = error {
                DispatchQueue.main.async {
                    self.appendToLog("Download failed: \(error.localizedDescription)")
                    self.resetRipButton()
                }
                return
            }

            guard let tempURL = tempURL else {
                DispatchQueue.main.async {
                    self.appendToLog("Download failed: No file received")
                    self.resetRipButton()
                }
                return
            }

            // Process the downloaded file
            self.processDownloadedFFmpeg(from: tempURL)
        }

        task.resume()
    }

    private func getCurrentArchitecture() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machine = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0)
            }
        }

        if let arch = machine {
            if arch.contains("arm64") {
                return "arm64"
            } else if arch.contains("x86_64") {
                return "x86_64"
            }
        }

        return "universal"
    }

    private func getFFmpegDownloadURL(for architecture: String) -> String {
        // Using static builds from a reliable source
        // Note: In production, you'd want to host these yourself or use official releases
        let baseURL = "https://evermeet.cx/ffmpeg"

        switch architecture {
        case "arm64":
            return "\(baseURL)/getrelease/ffmpeg/zip"
        case "x86_64":
            return "\(baseURL)/getrelease/ffmpeg/zip"
        default:
            return "\(baseURL)/getrelease/ffmpeg/zip"
        }
    }

    private func processDownloadedFFmpeg(from tempURL: URL) {
        let destinationPath = getApplicationSupportPath()
        let ffmpegPath = (destinationPath as NSString).appendingPathComponent("ffmpeg")

        DispatchQueue.main.async {
            self.appendToLog("Extracting FFmpeg...")
        }

        do {
            // If it's a zip file, extract it
            if tempURL.pathExtension.lowercased() == "zip" {
                try self.extractZip(from: tempURL, to: destinationPath)
            } else {
                // If it's a direct binary, copy it
                try FileManager.default.copyItem(at: tempURL, to: URL(fileURLWithPath: ffmpegPath))
            }

            // Make it executable
            let attributes = [FileAttributeKey.posixPermissions: 0o755]
            try FileManager.default.setAttributes(attributes, ofItemAtPath: ffmpegPath)

            DispatchQueue.main.async {
                self.appendToLog("FFmpeg installed successfully at: \(ffmpegPath)")
                self.appendToLog("FFmpeg is ready for use!")
                self.resetRipButton()
            }

        } catch {
            DispatchQueue.main.async {
                self.appendToLog("Failed to install FFmpeg: \(error.localizedDescription)")
                self.showAlert(title: "Installation Error",
                             message: "Failed to install FFmpeg. Please check your internet connection and try again.")
                self.resetRipButton()
            }
        }
    }

    private func extractZip(from sourceURL: URL, to destinationPath: String) throws {
        // Use the system unzip utility
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-o", sourceURL.path, "-d", destinationPath]

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            throw NSError(domain: "UnzipError", code: Int(process.terminationStatus),
                         userInfo: [NSLocalizedDescriptionKey: "Failed to extract zip file"])
        }
    }

    func resetRipButton() {
        ripButton.title = "Start Ripping"
        ripButton.isEnabled = true
    }

    // MARK: - FFmpeg Path Management

    func getBundledFFmpegPath() -> String? {
        // Check if FFmpeg is bundled in the app bundle (Contents/Resources)
        let bundlePath = Bundle.main.bundlePath
        let ffmpegPath = bundlePath.appending("/Contents/Resources/ffmpeg")
        if FileManager.default.fileExists(atPath: ffmpegPath) {
            return ffmpegPath
        }

        // Fallback to legacy path
        return Bundle.main.path(forResource: "ffmpeg", ofType: nil)
    }

    func getInstalledFFmpegPath() -> String {
        // Get path to FFmpeg in Application Support directory
        let appSupportPath = getApplicationSupportPath()
        return (appSupportPath as NSString).appendingPathComponent("ffmpeg")
    }

    func getFFmpegExecutablePath() -> String? {
        // Return the path to the FFmpeg executable, checking bundled first
        if let bundledPath = getBundledFFmpegPath(), FileManager.default.fileExists(atPath: bundledPath) {
            return bundledPath
        }

        let installedPath = getInstalledFFmpegPath()
        if FileManager.default.fileExists(atPath: installedPath) {
            return installedPath
        }

        // Check system PATH for FFmpeg
        if isFFmpegAvailable() {
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
                    if let output = String(data: data, encoding: .utf8) {
                        return output.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
            } catch {
                return nil
            }
        }

        return nil
    }
    
    // MARK: - Hardware Acceleration Detection
    
    func checkHardwareAccelerationSupport() -> Bool {
        guard let ffmpegPath = getFFmpegExecutablePath() else {
            return false
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffmpegPath)
        process.arguments = ["-hide_banner", "-hwaccels"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                // Check for VideoToolbox (macOS hardware acceleration)
                return output.contains("videotoolbox")
            }
        } catch {
            // If we can't check, assume no hardware acceleration
            return false
        }
        
        return false
    }
    
    func checkFFmpegAndHardwareAcceleration() {
        // Check if FFmpeg is available first
        ensureFFmpegAvailable()
        
        // Check if this is the first run and hardware acceleration hasn't been checked yet
        if !settingsManager.hardwareAccelerationChecked {
            DispatchQueue.main.async {
                self.performFirstRunHardwareAccelerationCheck()
            }
        }
    }
    
    private func performFirstRunHardwareAccelerationCheck() {
        // Only check if FFmpeg is available
        guard getFFmpegExecutablePath() != nil else {
            // FFmpeg not available, mark as checked and continue
            settingsManager.hardwareAccelerationChecked = true
            return
        }
        
        // Check if hardware acceleration is available
        let hardwareAccelSupported = checkHardwareAccelerationSupport()
        
        if hardwareAccelSupported {
            // Show dialog to user
            showHardwareAccelerationDialog()
        } else {
            // No hardware acceleration available, mark as checked
            settingsManager.hardwareAccelerationChecked = true
            appendToLog("Hardware acceleration not available on this system")
        }
    }
    
    private func showHardwareAccelerationDialog() {
        let alert = NSAlert()
        alert.messageText = "Hardware Acceleration Available"
        alert.informativeText = "Your system supports hardware acceleration for video encoding, which can significantly improve performance. Would you like to enable it?"
        alert.addButton(withTitle: "Enable")
        alert.addButton(withTitle: "Keep Disabled")
        alert.alertStyle = .informational
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            // User chose to enable hardware acceleration
            settingsManager.hardwareAcceleration = true
            appendToLog("Hardware acceleration enabled")
        } else {
            // User chose to keep it disabled
            settingsManager.hardwareAcceleration = false
            appendToLog("Hardware acceleration disabled by user choice")
        }
        
        // Mark as checked so we don't ask again
        settingsManager.hardwareAccelerationChecked = true
    }
}
