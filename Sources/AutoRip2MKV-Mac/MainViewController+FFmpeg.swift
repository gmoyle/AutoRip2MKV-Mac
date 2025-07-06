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
        
        return nil
    }
}
