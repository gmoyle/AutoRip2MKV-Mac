import Cocoa

class MainViewController: NSViewController {
    
    // UI Elements
    private var titleLabel: NSTextField!
    private var sourceLabel: NSTextField!
    private var sourceDropDown: NSPopUpButton!
    private var refreshDrivesButton: NSButton!
    private var browseSourceButton: NSButton!
    private var outputLabel: NSTextField!
    private var outputPathField: NSTextField!
    private var browseOutputButton: NSButton!
    private var ripButton: NSButton!
    private var progressIndicator: NSProgressIndicator!
    private var logTextView: NSTextView!
    private var scrollView: NSScrollView!
    
    // Drive Detection
    private var detectedDrives: [OpticalDrive] = []
    private var driveDetector = DriveDetector.shared
    private var settingsManager = SettingsManager.shared
    
    // DVD Ripper
    private var dvdRipper: DVDRipper!
    private var currentTitles: [DVDTitle] = []
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        setupUI()
        setupDVDRipper()
        loadSettings()
        refreshDrives()
    }
    
    private func setupUI() {
        // Title Label
        titleLabel = NSTextField(labelWithString: "AutoRip2MKV for Mac")
        titleLabel.font = NSFont.systemFont(ofSize: 24, weight: .bold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)
        
        // Source Path Section
        sourceLabel = NSTextField(labelWithString: "Source DVD/Blu-ray Drive:")
        sourceLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(sourceLabel)
        
        sourceDropDown = NSPopUpButton()
        sourceDropDown.translatesAutoresizingMaskIntoConstraints = false
        sourceDropDown.target = self
        sourceDropDown.action = #selector(driveSelectionChanged)
        view.addSubview(sourceDropDown)
        
        refreshDrivesButton = NSButton(title: "Refresh", target: self, action: #selector(refreshDrives))
        refreshDrivesButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(refreshDrivesButton)
        
        browseSourceButton = NSButton(title: "Browse", target: self, action: #selector(browseSourcePath))
        browseSourceButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(browseSourceButton)
        
        // Output Path Section
        outputLabel = NSTextField(labelWithString: "Output Directory:")
        outputLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(outputLabel)
        
        outputPathField = NSTextField()
        outputPathField.placeholderString = "Select output directory..."
        outputPathField.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(outputPathField)
        
        browseOutputButton = NSButton(title: "Browse", target: self, action: #selector(browseOutputPath))
        browseOutputButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(browseOutputButton)
        
        // Rip Button
        ripButton = NSButton(title: "Start Ripping", target: self, action: #selector(startRipping))
        ripButton.bezelStyle = .rounded
        ripButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(ripButton)
        
        // Progress Indicator
        progressIndicator = NSProgressIndicator()
        progressIndicator.style = .bar
        progressIndicator.isIndeterminate = true
        progressIndicator.isHidden = true
        progressIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(progressIndicator)
        
        // Log Text View
        logTextView = NSTextView()
        logTextView.isEditable = false
        logTextView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        
        scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.documentView = logTextView
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        setupConstraints()
    }
    
    private func setupDVDRipper() {
        dvdRipper = DVDRipper()
        dvdRipper.delegate = self
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Title
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            // Source Label
            sourceLabel.bottomAnchor.constraint(equalTo: sourceDropDown.topAnchor, constant: -5),
            sourceLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            
            // Output Label
            outputLabel.bottomAnchor.constraint(equalTo: outputPathField.topAnchor, constant: -5),
            outputLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            
            // Source Path
            sourceDropDown.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 40),
            sourceDropDown.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            sourceDropDown.trailingAnchor.constraint(equalTo: refreshDrivesButton.leadingAnchor, constant: -10),
            
            refreshDrivesButton.topAnchor.constraint(equalTo: sourceDropDown.topAnchor),
            refreshDrivesButton.trailingAnchor.constraint(equalTo: browseSourceButton.leadingAnchor, constant: -10),
            refreshDrivesButton.widthAnchor.constraint(equalToConstant: 80),
            
            browseSourceButton.topAnchor.constraint(equalTo: sourceDropDown.topAnchor),
            browseSourceButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            browseSourceButton.widthAnchor.constraint(equalToConstant: 80),
            
            // Output Path
            outputPathField.topAnchor.constraint(equalTo: sourceDropDown.bottomAnchor, constant: 20),
            outputPathField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            outputPathField.trailingAnchor.constraint(equalTo: browseOutputButton.leadingAnchor, constant: -10),
            
            browseOutputButton.topAnchor.constraint(equalTo: outputPathField.topAnchor),
            browseOutputButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            browseOutputButton.widthAnchor.constraint(equalToConstant: 80),
            
            // Rip Button
            ripButton.topAnchor.constraint(equalTo: outputPathField.bottomAnchor, constant: 30),
            ripButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            ripButton.widthAnchor.constraint(equalToConstant: 120),
            
            // Progress Indicator
            progressIndicator.topAnchor.constraint(equalTo: ripButton.bottomAnchor, constant: 20),
            progressIndicator.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            progressIndicator.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            // Log Text View
            scrollView.topAnchor.constraint(equalTo: progressIndicator.bottomAnchor, constant: 20),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20)
        ])
    }
    
    @objc private func browseSourcePath() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.title = "Select Source DVD/Blu-ray Directory"
        
        if let url = testingUtils.showFilePanel(openPanel, testPath: "/tmp/test_dvd", logHandler: { [weak self] logMessage in
            self?.appendToLog(logMessage)
        }) {
            // Add custom path to dropdown
            sourceDropDown.addItem(withTitle: "Custom: \(url.lastPathComponent)")
            sourceDropDown.selectItem(at: sourceDropDown.numberOfItems - 1)
            
            // Save the selection
            saveCurrentSettings()
        }
    }
    
    @objc private func browseOutputPath() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.title = "Select Output Directory"
        
        if let url = testingUtils.showFilePanel(openPanel, testPath: "/tmp/test_output", logHandler: { [weak self] logMessage in
            self?.appendToLog(logMessage)
        }) {
            outputPathField.stringValue = url.path
            saveCurrentSettings()
        }
    }
    
    @objc private func startRipping() {
        guard let sourcePath = getSelectedSourcePath(), !outputPathField.stringValue.isEmpty else {
            showAlert(title: "Error", message: "Please select both source and output directories.")
            return
        }
        
        // Check if FFmpeg is available
        installFFmpegIfNeeded()
        
        // Start the native DVD ripping process
        ripButton.isEnabled = false
        progressIndicator.isHidden = false
        progressIndicator.isIndeterminate = false
        progressIndicator.doubleValue = 0.0
        
        appendToLog("Starting native DVD ripping process...")
        appendToLog("Source: \(sourcePath)")
        appendToLog("Output: \(outputPathField.stringValue)")
        
        // Configure ripping
        let configuration = DVDRipper.RippingConfiguration(
            outputDirectory: outputPathField.stringValue,
            selectedTitles: [], // Rip all titles
            videoCodec: .h264,
            audioCodec: .aac,
            quality: .high,
            includeSubtitles: true,
            includeChapters: true
        )
        
        // Start ripping
        dvdRipper.startRipping(dvdPath: sourcePath, configuration: configuration)
        
        // Save current settings
        saveCurrentSettings()
    }
    
    private func appendToLog(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let logMessage = "[\(timestamp)] \(message)\n"
        
        logTextView.textStorage?.append(NSAttributedString(string: logMessage))
        logTextView.scrollToEndOfDocument(nil)
    }
    
    private func showAlert(title: String, message: String) {
        testingUtils.showAlert(title: title, message: message) { [weak self] alertTitle, alertMessage in
            self?.appendToLog("ALERT: \(alertTitle) - \(alertMessage)")
        }
    }
    
    private func isFFmpegAvailable() -> Bool {
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
    
    private func getFFmpegExecutablePath() -> String? {
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
            // Ignore errors
        }
        
        return nil
    }
    
    private func installFFmpegIfNeeded() {
        if !isFFmpegAvailable() {
            // Check if we have a bundled FFmpeg first
            if let bundledFFmpegPath = getBundledFFmpegPath(), 
               FileManager.default.fileExists(atPath: bundledFFmpegPath) {
                appendToLog("Using bundled FFmpeg: \(bundledFFmpegPath)")
                return
            }
            
            appendToLog("FFmpeg not found. Downloading FFmpeg binary...")
            
            // Disable the rip button during download
            ripButton.isEnabled = false
            ripButton.title = "Downloading FFmpeg..."
            
            // Download FFmpeg in background
            DispatchQueue.global(qos: .userInitiated).async {
                self.downloadAndInstallFFmpeg()
            }
        } else {
            appendToLog("FFmpeg is already installed and available.")
        }
    }
    
    private func getBundledFFmpegPath() -> String? {
        // Check if FFmpeg is bundled with the app
        guard let bundlePath = Bundle.main.resourcePath else { return nil }
        let ffmpegPath = (bundlePath as NSString).appendingPathComponent("ffmpeg")
        
        if FileManager.default.fileExists(atPath: ffmpegPath) {
            return ffmpegPath
        }
        
        // Check in application support directory
        let appSupportPath = getApplicationSupportPath()
        let appSupportFFmpegPath = (appSupportPath as NSString).appendingPathComponent("ffmpeg")
        
        if FileManager.default.fileExists(atPath: appSupportFFmpegPath) {
            return appSupportFFmpegPath
        }
        
        return nil
    }
    
    private func getApplicationSupportPath() -> String {
        let fileManager = FileManager.default
        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appPath = appSupportURL.appendingPathComponent("AutoRip2MKV-Mac")
        
        // Create directory if it doesn't exist
        if !fileManager.fileExists(atPath: appPath.path) {
            try? fileManager.createDirectory(at: appPath, withIntermediateDirectories: true)
        }
        
        return appPath.path
    }
    
    private func downloadAndInstallFFmpeg() {
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
    
    private func resetRipButton() {
        ripButton.title = "Start Ripping"
        ripButton.isEnabled = true
    }
    
    // MARK: - Drive Detection and Settings
    
    @objc private func refreshDrives() {
        detectedDrives = driveDetector.detectOpticalDrives()
        updateDriveDropdown()
        
        appendToLog("Detected \(detectedDrives.count) optical drive(s)")
        for drive in detectedDrives {
            appendToLog("  - \(drive.displayName) (\(drive.type))")
        }
    }
    
    private func updateDriveDropdown() {
        sourceDropDown.removeAllItems()
        
        if detectedDrives.isEmpty {
            sourceDropDown.addItem(withTitle: "No drives detected")
            sourceDropDown.isEnabled = false
        } else {
            sourceDropDown.isEnabled = true
            
            for drive in detectedDrives {
                let driveTypeString = drive.type == .dvd ? "DVD" : 
                                     drive.type == .bluray ? "Blu-ray" : "Unknown"
                let title = "\(drive.name) (\(driveTypeString))"
                sourceDropDown.addItem(withTitle: title)
            }
            
            // Select the previously selected drive if available
            let savedIndex = settingsManager.selectedDriveIndex
            if savedIndex < detectedDrives.count {
                sourceDropDown.selectItem(at: savedIndex)
            } else if detectedDrives.count == 1 {
                // Auto-select if only one drive
                sourceDropDown.selectItem(at: 0)
                settingsManager.selectedDriveIndex = 0
            }
        }
    }
    
    @objc private func driveSelectionChanged() {
        saveCurrentSettings()
    }
    
    private func getSelectedSourcePath() -> String? {
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
    
    private func loadSettings() {
        // Load output path
        if let lastOutputPath = settingsManager.lastOutputPath {
            outputPathField.stringValue = lastOutputPath
        }
    }
    
    private func saveCurrentSettings() {
        let sourcePath = getSelectedSourcePath()
        let outputPath = outputPathField.stringValue.isEmpty ? nil : outputPathField.stringValue
        let driveIndex = sourceDropDown.indexOfSelectedItem
        
        settingsManager.saveSettings(
            sourcePath: sourcePath,
            outputPath: outputPath,
            driveIndex: driveIndex
        )
    }
    
}

// MARK: - DVDRipperDelegate

extension MainViewController: DVDRipperDelegate {
    
    func ripperDidStart() {
        DispatchQueue.main.async {
            self.appendToLog("DVD ripper started")
        }
    }
    
    func ripperDidUpdateStatus(_ status: String) {
        DispatchQueue.main.async {
            self.appendToLog(status)
        }
    }
    
    func ripperDidUpdateProgress(_ progress: Double, currentTitle: DVDTitle?, totalTitles: Int) {
        DispatchQueue.main.async {
            self.progressIndicator.doubleValue = progress * 100.0
            
            if let title = currentTitle {
                self.appendToLog("Processing title \(title.number) - \(Int(progress * 100))% complete")
            }
        }
    }
    
    func ripperDidComplete() {
        DispatchQueue.main.async {
            self.appendToLog("DVD ripping completed successfully!")
            self.progressIndicator.isHidden = true
            self.ripButton.isEnabled = true
            self.ripButton.title = "Start Ripping"
            
            self.testingUtils.showAlert(
                title: "Ripping Complete",
                message: "DVD has been successfully ripped to MKV format.",
                style: .informational
            ) { [weak self] alertTitle, alertMessage in
                self?.appendToLog("ALERT: \(alertTitle) - \(alertMessage)")
            }
        }
    }
    
    func ripperDidFail(with error: Error) {
        DispatchQueue.main.async {
            self.appendToLog("Error: \(error.localizedDescription)")
            self.progressIndicator.isHidden = true
            self.ripButton.isEnabled = true
            self.ripButton.title = "Start Ripping"
            
            self.showAlert(title: "Ripping Failed", message: error.localizedDescription)
        }
    }
}
