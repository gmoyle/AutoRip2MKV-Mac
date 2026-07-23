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
    internal var progressStatusLabel: NSTextField!
    internal var totalRipSizeBytes: Int64 = 0
    internal var logTextView: NSTextView!
    internal var activeMediaRipper: MediaRipper?
    internal var scrollView: NSScrollView!

    // Embedded queue table
    internal var queueTableView: NSTableView!
    internal var queueScrollView: NSScrollView!
    internal var queueJobs: [ConversionQueue.ConversionJob] = []
    internal var queueEncodePhase = false  // false: reading disc, true: background encode

    // Collapsible log
    internal var logDisclosureButton: NSButton!
    internal var logDisclosureLabel: NSTextField!
    internal var logHeightConstraint: NSLayoutConstraint!

    // Automation Settings
    internal var autoRipCheckbox: NSButton!
    internal var autoEjectCheckbox: NSButton!
    internal var skipRippedCheckbox: NSButton!
    internal var settingsButton: NSButton!

    // Drive Detection - internal for extension access
    internal var detectedDrives: [OpticalDrive] = []
    internal var driveDetector = DriveDetector.shared
    internal var settingsManager = SettingsManager.shared
    internal var resolvedDiscTitle: String? = nil

    // DVD Ripper
    internal var dvdRipper: DVDRipper!
    private var currentTitles: [DVDTitle] = []

    // Conversion Queue
    internal let conversionQueue = ConversionQueue()

    // Settings Windows
    private var detailedSettingsWindowController: DetailedSettingsWindowController?

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        setupUI()
        setupDVDRipper()
        setupConversionQueue()
        settingsManager.setDefaultsIfNeeded()  // must run before loadSettings reads values
        loadSettings()
        refreshDrives()
        driveDetector.delegate = self
        driveDetector.startMonitoring()
        
        // Check FFmpeg and hardware acceleration on startup
        checkFFmpegAndHardwareAcceleration()

        // Warn if running from a non-permanent location (DMG, /tmp, Downloads)
        // TCC permission grants won't persist unless the app is in /Applications or ~/Applications
        checkInstallLocation()
    }

    private func checkInstallLocation() {
        let bundlePath = Bundle.main.bundlePath
        let permanent = ["/Applications/", "/Users/\(NSUserName())/Applications/"]
        let isInstalled = permanent.contains { bundlePath.hasPrefix($0) }
        guard !isInstalled else { return }

        // Only show once per app location to avoid nagging
        let key = "installWarningShown_\(bundlePath.hash)"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let alert = NSAlert()
            alert.messageText = "Move AutoRip2MKV to Applications"
            alert.informativeText = """
                AutoRip2MKV is running from:
                \(bundlePath)

                For disc access permissions to be remembered by macOS, the app must be in your Applications folder. If you leave it here, macOS may ask for permission every time you rip.

                Drag AutoRip2MKV to /Applications or ~/Applications to fix this.
                """
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    deinit {
        // Clean up delegate references and monitoring to prevent retain cycles
        driveDetector.delegate = nil
        driveDetector.stopMonitoring()
        dvdRipper?.delegate = nil
        conversionQueue.delegate = nil
        conversionQueue.mainDelegate = nil
        conversionQueue.ejectionDelegate = nil

        // Clean up window controllers
        detailedSettingsWindowController = nil
    }

    private func setupConversionQueue() {
        conversionQueue.ejectionDelegate = self
        conversionQueue.mainDelegate = self
    }

    private func setupUI() {
        setupTitleLabel()
        setupSourceSection()
        setupOutputSection()
        setupAutomationSettings()
        setupRipButton()
        setupProgressIndicator()
        setupQueueTable()
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
        sourceLabel = NSTextField(labelWithString: "Detected Disc:")
        sourceLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(sourceLabel)

        sourceDropDown = NSPopUpButton()
        sourceDropDown.translatesAutoresizingMaskIntoConstraints = false
        sourceDropDown.target = self
        sourceDropDown.action = #selector(driveSelectionChanged)
        sourceDropDown.isHidden = true  // Hide by default, show only when needed
        view.addSubview(sourceDropDown)

        refreshDrivesButton = NSButton(title: "Refresh", target: self, action: #selector(refreshDrives))
        refreshDrivesButton.translatesAutoresizingMaskIntoConstraints = false
        refreshDrivesButton.isHidden = false  // Show refresh button for manual refresh
        view.addSubview(refreshDrivesButton)

        browseSourceButton = NSButton(title: "Browse", target: self, action: #selector(browseSourcePath))
        browseSourceButton.translatesAutoresizingMaskIntoConstraints = false
        browseSourceButton.isHidden = true  // Hide by default
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

        skipRippedCheckbox = NSButton(
            checkboxWithTitle: "Skip discs already ripped (hold ⌥ on insert to re-rip)",
            target: self,
            action: #selector(skipRippedToggled)
        )
        skipRippedCheckbox.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(skipRippedCheckbox)

        settingsButton = NSButton(title: "Settings...", target: self, action: #selector(showSettings))
        settingsButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(settingsButton)
    }

    private func setupRipButton() {
        ripButton = NSButton(title: "Start Ripping", target: self, action: #selector(ripButtonPressed))
        ripButton.bezelStyle = .rounded
        ripButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(ripButton)
    }

    @objc private func ripButtonPressed() {
        if activeMediaRipper != nil {
            cancelRipping()
        } else {
            startRipping()
        }
    }

    @objc private func cancelRipping() {
        appendToLog("Cancelling rip...")
        activeMediaRipper?.cancelRipping()
        activeMediaRipper = nil
        // Clean up any temp VOB files left behind
        let tmp = NSTemporaryDirectory()
        if let files = try? FileManager.default.contentsOfDirectory(atPath: tmp) {
            for file in files where file.hasPrefix("temp_dvd_title_") && file.hasSuffix(".vob") {
                try? FileManager.default.removeItem(atPath: tmp + file)
            }
        }
        resetRipUI()
    }

    internal func resetRipUI() {
        ripButton.title = "Start Ripping"
        ripButton.isEnabled = true
        progressIndicator.doubleValue = 0
        progressIndicator.isHidden = true
        progressStatusLabel.stringValue = ""
        progressStatusLabel.isHidden = true
        updateDriveDropdown()
    }

    private func setupProgressIndicator() {
        progressIndicator = NSProgressIndicator()
        progressIndicator.style = .bar
        progressIndicator.isIndeterminate = false
        progressIndicator.minValue = 0
        progressIndicator.maxValue = 100
        progressIndicator.doubleValue = 0
        progressIndicator.isHidden = true
        progressIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(progressIndicator)

        progressStatusLabel = NSTextField(labelWithString: "")
        progressStatusLabel.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        progressStatusLabel.textColor = NSColor.secondaryLabelColor
        progressStatusLabel.alignment = .center
        progressStatusLabel.isHidden = true
        progressStatusLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(progressStatusLabel)
    }

    private func setupQueueTable() {
        queueTableView = NSTableView()
        queueTableView.rowHeight = 22
        queueTableView.allowsMultipleSelection = false
        queueTableView.usesAlternatingRowBackgroundColors = true

        let columns: [(id: String, title: String, width: CGFloat)] = [
            ("title", "Disc Title", 220),
            ("status", "Status", 170),
            ("progress", "Progress", 120),
            ("duration", "Duration", 80)
        ]
        for spec in columns {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(spec.id))
            column.title = spec.title
            column.width = spec.width
            queueTableView.addTableColumn(column)
        }

        queueTableView.dataSource = self
        queueTableView.delegate = self
        queueTableView.menu = makeQueueContextMenu()

        queueScrollView = NSScrollView()
        queueScrollView.hasVerticalScroller = true
        queueScrollView.documentView = queueTableView
        queueScrollView.borderType = .bezelBorder
        queueScrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(queueScrollView)
    }

    private func setupLogTextView() {
        logDisclosureButton = NSButton(title: "Show Log", target: self, action: #selector(toggleLogVisibility))
        logDisclosureButton.bezelStyle = .disclosure
        logDisclosureButton.setButtonType(.pushOnPushOff)
        logDisclosureButton.state = .off
        logDisclosureButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(logDisclosureButton)

        let disclosureLabel = NSTextField(labelWithString: "Log")
        disclosureLabel.font = NSFont.systemFont(ofSize: 12)
        disclosureLabel.textColor = .secondaryLabelColor
        disclosureLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(disclosureLabel)
        logDisclosureLabel = disclosureLabel

        logTextView = NSTextView()
        logTextView.isEditable = false
        logTextView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)

        scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.documentView = logTextView
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.isHidden = true
        view.addSubview(scrollView)
    }

    @objc private func toggleLogVisibility() {
        let show = logDisclosureButton.state == .on
        scrollView.isHidden = !show
        logHeightConstraint.constant = show ? 180 : 0
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
        appendToLog("startRipping method called")

        // Block ripping if not installed — TCC grants won't persist from a DMG or Downloads
        let bundlePath = Bundle.main.bundlePath
        let permanent = ["/Applications/", "/Users/\(NSUserName())/Applications/"]
        if !permanent.contains(where: { bundlePath.hasPrefix($0) }) {
            let alert = NSAlert()
            alert.messageText = "Install Required Before Ripping"
            alert.informativeText = "AutoRip2MKV must be in your Applications folder for disc access permissions to be remembered by macOS. Drag it from the DMG to Applications, then relaunch."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }

        // Check if we have a detected disc
        guard let currentDrive = detectedDrives.first else {
            showAlert(title: "No Disc Detected", message: "Please insert a DVD or BluRay disc to start ripping.")
            return
        }

        guard !conversionQueue.hasActiveJob(forSourcePath: currentDrive.mountPoint) else {
            appendToLog("A rip for \(currentDrive.displayName) is already queued or in progress.")
            showAlert(title: "Already Ripping",
                      message: "A rip for this disc is already in progress or queued. Open the Queue window for details.")
            return
        }

        guard !outputPathField.stringValue.isEmpty else {
            showAlert(title: "Error", message: "Please select an output directory.")
            return
        }

        // Check if FFmpeg is available
        installFFmpegIfNeeded()

        // Detect media type
        let mediaRipper = MediaRipper()
        let mediaType = mediaRipper.detectMediaType(path: currentDrive.mountPoint)

        appendToLog("Starting rip of \(currentDrive.displayName)...")
        appendToLog("Source: \(currentDrive.mountPoint)")
        appendToLog("Output: \(outputPathField.stringValue)")

        // Validate source path exists
        let videoTSSource = currentDrive.mountPoint.appending("/VIDEO_TS")
        guard FileManager.default.fileExists(atPath: videoTSSource) else {
            showAlert(title: "Error", message: "Source DVD not found. Please ensure the disc is properly inserted.")
            return
        }

        // Configure ripping for direct MediaRipper
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
            mediaType: mediaType,
            autoDeinterlace: settingsManager.autoDeinterlace,
            plexName: resolvedDiscTitle
        )

        saveCurrentSettings()

        let discTitle = resolvedDiscTitle ?? currentDrive.name
        let driveTypeString = currentDrive.type == .dvd ? "DVD" : currentDrive.type == .bluray ? "Blu-ray" : "Unknown"
        appendToLog("Queued: \(discTitle) (\(driveTypeString))")

        conversionQueue.addJob(
            sourcePath: currentDrive.mountPoint,
            outputDirectory: outputPathField.stringValue,
            configuration: configuration,
            mediaType: mediaType,
            discTitle: discTitle
        )
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
        appendToLog("Scanning for optical drives with movie content...")
        detectedDrives = driveDetector.detectOpticalDrives()
        updateDriveDropdown()

        if detectedDrives.isEmpty {
            appendToLog("No movie discs detected. Please insert a DVD (with VIDEO_TS folder) or Blu-ray (with BDMV folder).")
        } else {
            appendToLog("Found \(detectedDrives.count) movie disc(s):")
            for drive in detectedDrives {
                let driveTypeString = drive.type == .dvd ? "DVD" : drive.type == .bluray ? "Blu-ray" : "Unknown"
                appendToLog("  - \(drive.displayName) (\(driveTypeString))")
            }
        }
    }

    private func updateDriveDropdown() {
        // Update the source label to show current disc status
        if detectedDrives.isEmpty {
            resolvedDiscTitle = nil
            sourceLabel.stringValue = "No disc detected - Please insert a DVD or BluRay"
            ripButton.isEnabled = false
        } else {
            let drive = detectedDrives.first!
            let driveTypeString = drive.type == .dvd ? "DVD" : drive.type == .bluray ? "Blu-ray" : "Unknown"
            let displayTitle = resolvedDiscTitle ?? drive.name
            sourceLabel.stringValue = "\(displayTitle) (\(driveTypeString)) - Ready to rip"
            ripButton.isEnabled = true
        }
        
        // The dropdown is now hidden, but we'll keep the logic for advanced users
        let currentSelection = sourceDropDown.titleOfSelectedItem
        let _ = sourceDropDown.indexOfSelectedItem
        
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

            // Try to restore the previous selection by matching drive names
            var selectionRestored = false
            if let previousSelection = currentSelection, !previousSelection.contains("No drives detected") {
                for (index, drive) in detectedDrives.enumerated() {
                    let driveTypeString = drive.type == .dvd ? "DVD" :
                                         drive.type == .bluray ? "Blu-ray" : "Unknown"
                    let title = "\(drive.name) (\(driveTypeString))"
                    if title == previousSelection || previousSelection.contains(drive.name) {
                        sourceDropDown.selectItem(at: index)
                        selectionRestored = true
                        break
                    }
                }
            }
            
            // If selection wasn't restored, try using saved index
            if !selectionRestored {
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

    @objc internal func skipRippedToggled() {
        settingsManager.skipRippedDiscs = skipRippedCheckbox.state == .on
        appendToLog("Skip already-ripped discs \(settingsManager.skipRippedDiscs ? "enabled" : "disabled")")
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
        DispatchQueue.main.async {
            self.detectedDrives.append(drive)
            self.appendToLog("New disc detected: \(drive.displayName)")
            self.resolvedDiscTitle = nil
            self.updateDriveDropdown()
            // Auto-rip only after the title lookup resolves (or fails) so the
            // rip can use Plex-style "Movie (Year)" naming from the start
            self.lookupDiscTitle(volumeName: drive.name) { title in
                self.resolvedDiscTitle = title
                self.updateDriveDropdown()
                if let t = title { self.appendToLog("Disc identified: \(t)") }
                self.autoStartRipping(for: drive)
            }
        }
    }

    func driveDetector(_ detector: DriveDetector, didEjectDisc drive: OpticalDrive) {
        DispatchQueue.main.async {
            self.detectedDrives.removeAll { $0.mountPoint == drive.mountPoint }
            self.resolvedDiscTitle = nil
            self.appendToLog("Disc ejected: \(drive.displayName)")
            self.updateDriveDropdown()
        }
    }

    /// If the disc was already ripped into the current output directory with the
    /// same settings, returns the existing rip's directory; otherwise nil.
    internal func findCompletedRip(for drive: OpticalDrive,
                                   mediaType: MediaRipper.MediaType,
                                   configuration: MediaRipper.RippingConfiguration) -> String? {
        let ripper = MediaRipper()
        let dir: String
        if let plexBase = ripper.plexBaseName(from: configuration) {
            dir = outputPathField.stringValue.appending("/\(plexBase)")
        } else {
            let movieName = ripper.extractMovieName(from: drive.mountPoint, mediaType: mediaType)
            dir = outputPathField.stringValue.appending("/\(mediaType.folderName)/\(movieName)")
        }
        let markerPath = dir.appending("/rip_complete.json")

        guard FileManager.default.fileExists(atPath: markerPath),
              let contents = try? FileManager.default.contentsOfDirectory(atPath: dir),
              contents.contains(where: { $0.hasSuffix(".mkv") }) else {
            return nil
        }

        // Settings changed since that rip? Treat as not ripped so it re-rips.
        if let data = try? Data(contentsOf: URL(fileURLWithPath: markerPath)),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let savedSettings = json["settings"] as? [String: String],
           savedSettings != ConversionQueue.settingsFingerprint(of: configuration) {
            appendToLog("Settings changed since the last rip of \(drive.displayName) — re-ripping.")
            return nil
        }

        return dir
    }

    /// Blu-ray can be ripped if MakeMKV is available (preferred) or the user has
    /// supplied a libaacs key database.
    internal func blurayDecryptionReady() -> Bool {
        if settingsManager.useMakeMKVForBluRay && MakeMKVBackend.isInstalled { return true }
        let keydb = NSString(string: "~/.config/aacs/KEYDB.cfg").expandingTildeInPath
        return FileManager.default.fileExists(atPath: keydb)
    }

    private func showBluRaySetupAlert() {
        let alert = NSAlert()
        alert.messageText = "Blu-ray Ripping Needs MakeMKV"
        alert.informativeText = """
            DVDs rip with no setup, but Blu-ray discs use AACS/BD+ protection that \
            AutoRip2MKV can't decrypt on its own.

            Install MakeMKV (free during beta) from makemkv.com — AutoRip2MKV will \
            use it automatically to handle Blu-ray decryption. Advanced users can \
            instead supply a libaacs key database at ~/.config/aacs/KEYDB.cfg.

            The disc has been ejected. Reinsert it after installing MakeMKV.
            """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    internal func autoStartRipping(for drive: OpticalDrive) {
        guard settingsManager.autoRipEnabled else {
            appendToLog("Auto-ripping is disabled. Click 'Start Ripping' to manually start ripping.")
            return
        }

        guard !conversionQueue.hasActiveJob(forSourcePath: drive.mountPoint) else {
            appendToLog("Skipping auto-rip: job already active for \(drive.displayName)")
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

        // Blu-ray needs MakeMKV (or a libaacs key database). If neither is set up,
        // don't start a rip that will fail — tell the user how to fix it.
        if mediaType == .bluray || mediaType == .bluray4K {
            guard blurayDecryptionReady() else {
                appendToLog("Blu-ray detected but no decryption backend is available.")
                showBluRaySetupAlert()
                if settingsManager.autoEjectEnabled { ejectCurrentDisk() }
                return
            }
        }

        appendToLog("Auto-starting rip of \(drive.displayName)...")

        // Configure ripping using saved settings for direct MediaRipper
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
            mediaType: mediaType,
            autoDeinterlace: settingsManager.autoDeinterlace,
            plexName: resolvedDiscTitle
        )

        // Skip discs already ripped with the same settings; a settings change
        // re-rips automatically. Hold Option on insert (or use Start Ripping)
        // to force a re-rip.
        if settingsManager.skipRippedDiscs {
            if NSEvent.modifierFlags.contains(.option) {
                appendToLog("Option key held — forcing re-rip of \(drive.displayName).")
            } else if let existingDir = findCompletedRip(
                for: drive, mediaType: mediaType, configuration: configuration) {
                appendToLog("Already ripped with current settings — skipping: \(existingDir)")
                appendToLog("Hold ⌥ while inserting, or click Start Ripping, to rip again.")
                if settingsManager.autoEjectEnabled {
                    ejectCurrentDisk()
                }
                return
            }
        }

        saveCurrentSettings()

        let autoRipTitle = resolvedDiscTitle ?? drive.name
        let autodriveTypeString = drive.type == .dvd ? "DVD" : drive.type == .bluray ? "Blu-ray" : "Unknown"
        appendToLog("Queued: \(autoRipTitle) (\(autodriveTypeString))")

        conversionQueue.addJob(
            sourcePath: drive.mountPoint,
            outputDirectory: outputPathField.stringValue,
            configuration: configuration,
            mediaType: mediaType,
            discTitle: autoRipTitle
        )
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
