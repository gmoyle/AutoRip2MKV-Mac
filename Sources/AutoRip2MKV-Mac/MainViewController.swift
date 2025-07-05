import Cocoa

class MainViewController: NSViewController {
    
    // UI Elements
    // UI Components - internal for extension access
    internal var titleLabel: NSTextField!
    internal var sourceLabel: NSTextField!
    internal var sourceDropDown: NSPopUpButton!
    internal var refreshDrivesButton: NSButton!
    internal var browseSourceButton: NSButton!
    internal var outputLabel: NSTextField!
    internal var outputPathField: NSTextField!
    internal var browseOutputButton: NSButton!
    internal var ripButton: NSButton!
    internal var progressIndicator: NSProgressIndicator!
    internal var logTextView: NSTextView!
    internal var scrollView: NSScrollView!
    
    // Automation Settings
    internal var autoRipCheckbox: NSButton!
    internal var autoEjectCheckbox: NSButton!
    internal var settingsButton: NSButton!
    
    // Drive Detection - internal for extension access
    internal var detectedDrives: [OpticalDrive] = []
    internal var driveDetector = DriveDetector.shared
    internal var settingsManager = SettingsManager.shared
    
    // DVD Ripper
    private var dvdRipper: DVDRipper!
    private var currentTitles: [DVDTitle] = []
    
    // Settings Window
    private var detailedSettingsWindowController: DetailedSettingsWindowController?
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        setupUI()
        setupDVDRipper()
        loadSettings()
        refreshDrives()
        driveDetector.delegate = self
        driveDetector.startMonitoring()
        settingsManager.setDefaultsIfNeeded()
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
        
        // Automation Settings
        autoRipCheckbox = NSButton(checkboxWithTitle: "Auto-rip inserted discs", target: self, action: #selector(autoRipToggled))
        autoRipCheckbox.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(autoRipCheckbox)
        
        autoEjectCheckbox = NSButton(checkboxWithTitle: "Auto-eject after ripping", target: self, action: #selector(autoEjectToggled))
        autoEjectCheckbox.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(autoEjectCheckbox)
        
        settingsButton = NSButton(title: "Settings...", target: self, action: #selector(showSettings))
        settingsButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(settingsButton)
        
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
            
            // Automation Settings
            autoRipCheckbox.topAnchor.constraint(equalTo: outputPathField.bottomAnchor, constant: 20),
            autoRipCheckbox.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            
            autoEjectCheckbox.topAnchor.constraint(equalTo: autoRipCheckbox.bottomAnchor, constant: 5),
            autoEjectCheckbox.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            
            settingsButton.topAnchor.constraint(equalTo: autoEjectCheckbox.topAnchor),
            settingsButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            settingsButton.widthAnchor.constraint(equalToConstant: 80),
            
            // Rip Button
            ripButton.topAnchor.constraint(equalTo: autoEjectCheckbox.bottomAnchor, constant: 20),
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
        
        if let url = testingUtils.showFilePanel(
            openPanel, testPath: "/tmp/test_dvd", logHandler: { [weak self] logMessage in
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
        
        if let url = testingUtils.showFilePanel(
            openPanel, testPath: "/tmp/test_output", logHandler: { [weak self] logMessage in
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
    
    // MARK: - Automation Settings Actions
    
    @objc private func autoRipToggled() {
        settingsManager.autoRipEnabled = autoRipCheckbox.state == .on
        appendToLog("Auto-rip \(settingsManager.autoRipEnabled ? "enabled" : "disabled")")
    }
    
    @objc private func autoEjectToggled() {
        settingsManager.autoEjectEnabled = autoEjectCheckbox.state == .on
        appendToLog("Auto-eject \(settingsManager.autoEjectEnabled ? "enabled" : "disabled")")
    }
    
    @objc private func showSettings() {
        print("[DEBUG] showSettings called - using DetailedSettingsWindowController")
        
        // Create or reuse the detailed settings window controller
        if detailedSettingsWindowController == nil {
            detailedSettingsWindowController = DetailedSettingsWindowController()
        }
        
        // Show the window
        detailedSettingsWindowController?.showWindow(nil)
        print("[DEBUG] Detailed settings window should be visible now")
    }
    
    
}

// MARK: - DriveDetectorDelegate

extension MainViewController: DriveDetectorDelegate {
    func driveDetector(_ detector: DriveDetector, didDetectNewDisc drive: OpticalDrive) {
        appendToLog("New disc detected: \(drive.displayName)")
        autoStartRipping(for: drive)
    }
    
    func driveDetector(_ detector: DriveDetector, didEjectDisc drive: OpticalDrive) {
        appendToLog("Disc ejected: \(drive.displayName)")
    }
    
    private func autoStartRipping(for drive: OpticalDrive) {
        guard settingsManager.autoRipEnabled else {
            appendToLog("Auto-ripping is disabled. Insert disc manually to start ripping.")
            return
        }
        
        guard !outputPathField.stringValue.isEmpty else {
            showAlert(title: "Error", message: "Output directory must be set for auto-ripping.")
            return
        }
        
        // Check if FFmpeg is available
        installFFmpegIfNeeded()
        
        // Start the native DVD ripping process
        ripButton.isEnabled = false
        progressIndicator.isHidden = false
        progressIndicator.isIndeterminate = false
        progressIndicator.doubleValue = 0.0
        
        appendToLog("Starting automated ripping process for: \(drive.displayName)")
        
        // Configure ripping using saved settings
        let videoCodec: DVDRipper.RippingConfiguration.VideoCodec = settingsManager.videoCodec == "h265" ? .h265 : .h264
        let audioCodec: DVDRipper.RippingConfiguration.AudioCodec = settingsManager.audioCodec == "ac3" ? .ac3 : .aac
        let quality: DVDRipper.RippingConfiguration.RippingQuality = {
            switch settingsManager.quality {
            case "low": return .low
            case "medium": return .medium
            case "high": return .high
            default: return .medium
            }
        }()
        
        let configuration = DVDRipper.RippingConfiguration(
            outputDirectory: outputPathField.stringValue,
            selectedTitles: [], // Rip all titles
            videoCodec: videoCodec,
            audioCodec: audioCodec,
            quality: quality,
            includeSubtitles: true,
            includeChapters: true
        )
        dvdRipper.startRipping(dvdPath: drive.mountPoint, configuration: configuration)
        
        // Save current settings
        saveCurrentSettings()
    }
}
