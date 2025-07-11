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
    internal var queueButton: NSButton!

    // Drive Detection - internal for extension access
    internal var detectedDrives: [OpticalDrive] = []
    internal var driveDetector = DriveDetector.shared
    internal var settingsManager = SettingsManager.shared

    // DVD Ripper
    internal var dvdRipper: DVDRipper!
    private var currentTitles: [DVDTitle] = []

    // Conversion Queue
    internal let conversionQueue = ConversionQueue()

    // Settings Windows
    private var detailedSettingsWindowController: DetailedSettingsWindowController?
    private var queueWindowController: QueueWindowController?

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        setupUI()
        setupDVDRipper()
        setupConversionQueue()
        loadSettings()
        refreshDrives()
        driveDetector.delegate = self
        driveDetector.startMonitoring()
        settingsManager.setDefaultsIfNeeded()
    }

    deinit {
        // Clean up delegate references and monitoring to prevent retain cycles
        driveDetector.delegate = nil
        driveDetector.stopMonitoring()
        dvdRipper?.delegate = nil
        conversionQueue.delegate = nil
        conversionQueue.ejectionDelegate = nil

        // Clean up window controllers
        detailedSettingsWindowController = nil
        queueWindowController = nil
    }

    private func setupConversionQueue() {
        conversionQueue.ejectionDelegate = self
    }

    private func setupUI() {
        setupTitleLabel()
        setupSourceSection()
        setupOutputSection()
        setupAutomationSettings()
        setupRipButton()
        setupProgressIndicator()
        setupLogTextView()
        setupConstraints()
    }

    private func setupTitleLabel() {
        titleLabel = NSTextField(labelWithString: "AutoRip2MKV for Mac")
        titleLabel.font = NSFont.systemFont(ofSize: 24, weight: .bold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)
    }

    private func setupSourceSection() {
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
    }

    private func setupOutputSection() {
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
    }

    private func setupAutomationSettings() {
        autoRipCheckbox = NSButton(
            checkboxWithTitle: "Auto-rip inserted discs",
            target: self,
            action: #selector(autoRipToggled)
        )
        autoRipCheckbox.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(autoRipCheckbox)

        autoEjectCheckbox = NSButton(
            checkboxWithTitle: "Auto-eject after ripping",
            target: self,
            action: #selector(autoEjectToggled)
        )
        autoEjectCheckbox.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(autoEjectCheckbox)

        settingsButton = NSButton(title: "Settings...", target: self, action: #selector(showSettings))
        settingsButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(settingsButton)

        queueButton = NSButton(title: "Queue", target: self, action: #selector(showQueue))
        queueButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(queueButton)
    }

    private func setupRipButton() {
        ripButton = NSButton(title: "Start Ripping", target: self, action: #selector(startRipping))
        ripButton.bezelStyle = .rounded
        ripButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(ripButton)
    }

    private func setupProgressIndicator() {
        progressIndicator = NSProgressIndicator()
        progressIndicator.style = .bar
        progressIndicator.isIndeterminate = true
        progressIndicator.isHidden = true
        progressIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(progressIndicator)
    }

    private func setupLogTextView() {
        logTextView = NSTextView()
        logTextView.isEditable = false
        logTextView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)

        scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.documentView = logTextView
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
    }

    private func setupDVDRipper() {
        dvdRipper = DVDRipper()
        dvdRipper.delegate = self
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

    @objc internal func startRipping() {
        guard let sourcePath = getSelectedSourcePath(), !outputPathField.stringValue.isEmpty else {
            showAlert(title: "Error", message: "Please select both source and output directories.")
            return
        }

        // Check if FFmpeg is available
        installFFmpegIfNeeded()

        // Detect media type
        let mediaRipper = MediaRipper()
        let mediaType = mediaRipper.detectMediaType(path: sourcePath)

        // Generate disc title from source path or drive info
        let discTitle = generateDiscTitle(from: sourcePath)

        appendToLog("Adding \(discTitle) to conversion queue...")
        appendToLog("Source: \(sourcePath)")
        appendToLog("Output: \(outputPathField.stringValue)")

        // Configure ripping for the queue
        let configuration = MediaRipper.RippingConfiguration(
            outputDirectory: outputPathField.stringValue,
            selectedTitles: [], // Rip all titles
            videoCodec: settingsManager.videoCodec == "h265" ? .h265 : .h264,
            audioCodec: settingsManager.audioCodec == "ac3" ? .ac3 : .aac,
            quality: {
                switch settingsManager.quality {
                case "low": return .low
                case "medium": return .medium
                case "high": return .high
                default: return .medium
                }
            }(),
            includeSubtitles: true,
            includeChapters: true,
            mediaType: mediaType
        )

        // Add to queue instead of starting immediately
        let jobId = conversionQueue.addJob(
            sourcePath: sourcePath,
            outputDirectory: outputPathField.stringValue,
            configuration: configuration,
            mediaType: mediaType,
            discTitle: discTitle
        )

        appendToLog("Added to queue with ID: \(jobId.uuidString)")
        appendToLog("Disc will be ejected automatically after reading is complete")

        // Save current settings
        saveCurrentSettings()

        // Show queue window to monitor progress
        showQueue()
    }

    func generateDiscTitle(from sourcePath: String) -> String {
        // If no drives are detected, extract from source path
        if detectedDrives.isEmpty {
            let pathComponent = URL(fileURLWithPath: sourcePath).lastPathComponent
            return pathComponent.isEmpty ? "Unknown Disc" : pathComponent
        }

        // Try to get disc title from selected drive using the utility method
        let selectedIndex = sourceDropDown.indexOfSelectedItem
        if selectedIndex >= 0 && selectedIndex < detectedDrives.count {
            let selectedDrive = detectedDrives[selectedIndex]
            return selectedDrive.displayName
        }

        // Fall back to last path component
        let pathComponent = URL(fileURLWithPath: sourcePath).lastPathComponent
        return pathComponent.isEmpty ? "Unknown Disc" : pathComponent
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

    @objc internal func autoRipToggled() {
        settingsManager.autoRipEnabled = autoRipCheckbox.state == .on
        appendToLog("Auto-rip \(settingsManager.autoRipEnabled ? "enabled" : "disabled")")
    }

    @objc internal func autoEjectToggled() {
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

    @objc internal func showQueue() {
        // Create or reuse the queue window controller
        if queueWindowController == nil {
            queueWindowController = QueueWindowController(conversionQueue: conversionQueue)
        }

        // Show the window
        queueWindowController?.showWindow(nil)
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

    internal func autoStartRipping(for drive: OpticalDrive) {
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

        // Detect media type
        let mediaRipper = MediaRipper()
        let mediaType = mediaRipper.detectMediaType(path: drive.mountPoint)

        appendToLog("Auto-adding \(drive.displayName) to conversion queue...")

        // Configure ripping using saved settings for the queue
        let configuration = MediaRipper.RippingConfiguration(
            outputDirectory: outputPathField.stringValue,
            selectedTitles: [], // Rip all titles
            videoCodec: settingsManager.videoCodec == "h265" ? .h265 : .h264,
            audioCodec: settingsManager.audioCodec == "ac3" ? .ac3 : .aac,
            quality: {
                switch settingsManager.quality {
                case "low": return .low
                case "medium": return .medium
                case "high": return .high
                default: return .medium
                }
            }(),
            includeSubtitles: true,
            includeChapters: true,
            mediaType: mediaType
        )

        // Add to queue for processing
        let jobId = conversionQueue.addJob(
            sourcePath: drive.mountPoint,
            outputDirectory: outputPathField.stringValue,
            configuration: configuration,
            mediaType: mediaType,
            discTitle: drive.displayName
        )

        appendToLog("Auto-added to queue with ID: \(jobId.uuidString)")
        appendToLog("Disc will be ejected automatically after reading is complete")

        // Save current settings
        saveCurrentSettings()
    }
}

// MARK: - ConversionQueueEjectionDelegate

extension MainViewController: ConversionQueueEjectionDelegate {
    func queueShouldEjectDisc(sourcePath: String) {
        // Only eject if auto-eject is enabled
        guard settingsManager.autoEjectEnabled else {
            appendToLog("Disc reading complete. Auto-eject is disabled - manual ejection required.")
            return
        }

        // Find the drive that matches the source path
        if let drive = detectedDrives.first(where: { $0.mountPoint == sourcePath }) {
            appendToLog("Auto-ejecting \(drive.displayName) after successful extraction...")

            DispatchQueue.global(qos: .background).async {
                let result = self.ejectDisk(at: drive.devicePath)

                DispatchQueue.main.async {
                    if result {
                        self.appendToLog("\(drive.displayName) ejected successfully - ready for next disc")
                    } else {
                        self.appendToLog("Failed to eject \(drive.displayName) - manual ejection may be required")
                    }
                }
            }
        } else {
            appendToLog("Disc reading complete. Could not find drive for auto-ejection.")
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
}
