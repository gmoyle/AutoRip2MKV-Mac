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
    internal var reviewRipsButton: NSButton!
    private var routingReviewWindowController: RoutingReviewWindowController?
    /// True while a queue-driven rip (e.g. Blu-ray) is extracting, so the rip
    /// button acts as a Cancel control.
    internal var queueRipInProgress = false

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

        // Opens the non-blocking Movie/TV routing review. Title carries a badge
        // count so pending decisions are visible without blocking rips.
        reviewRipsButton = NSButton(title: "Review Rips", target: self, action: #selector(showRoutingReview))
        reviewRipsButton.translatesAutoresizingMaskIntoConstraints = false
        reviewRipsButton.isHidden = true  // shown only when items are pending
        view.addSubview(reviewRipsButton)

        NotificationCenter.default.addObserver(
            self, selector: #selector(pendingRoutingsChanged),
            name: PendingRoutingQueue.didChangeNotification, object: nil)
        updateReviewRipsButton()
    }

    /// Reflect the pending-routing count in the Review Rips button (shown only
    /// when there's something to review).
    @objc internal func pendingRoutingsChanged() {
        DispatchQueue.main.async { [weak self] in self?.updateReviewRipsButton() }
    }

    private func updateReviewRipsButton() {
        let count = PendingRoutingQueue.shared.count
        reviewRipsButton?.isHidden = count == 0
        reviewRipsButton?.title = count > 0 ? "Review Rips (\(count))" : "Review Rips"
    }

    @objc private func showRoutingReview() {
        if routingReviewWindowController == nil {
            routingReviewWindowController = RoutingReviewWindowController()
        }
        routingReviewWindowController?.showWindow(nil)
        routingReviewWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func setupRipButton() {
        ripButton = NSButton(title: "Start Ripping", target: self, action: #selector(ripButtonPressed))
        ripButton.bezelStyle = .rounded
        ripButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(ripButton)
    }

    @objc private func ripButtonPressed() {
        if queueRipInProgress {
            cancelQueueRip()
        } else if activeMediaRipper != nil {
            cancelRipping()
        } else {
            startRipping()
        }
    }

    /// Cancel a queue-driven rip in progress (Blu-ray and any queued job). Cleanly
    /// terminates the active ripper — no orphaned makemkvcon — and resets the UI.
    @objc private func cancelQueueRip() {
        appendToLog("Cancelling rip...")
        if conversionQueue.cancelActiveJob() {
            appendToLog("Rip cancelled.")
        } else {
            appendToLog("No active rip to cancel.")
        }
        queueRipInProgress = false
        resetRipUI()
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
        queueRipInProgress = false
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

    /// If the disc was already ripped with the same settings, returns a short
    /// description of the existing rip (its output location); otherwise nil.
    ///
    /// Uses the central rip registry ([[RipHistoryStore]]) keyed by disc identity,
    /// which is independent of where the output files live — so it stays correct
    /// even after content routing moves a rip into a Plex library root or the
    /// user reorganizes their library. Falls back to legacy per-folder
    /// rip_complete.json markers so rips made before the registry are recognized.
    internal func findCompletedRip(for drive: OpticalDrive,
                                   mediaType: MediaRipper.MediaType,
                                   configuration: MediaRipper.RippingConfiguration) -> String? {
        let identity = DiscIdentity.compute(forDiscAt: drive.mountPoint)
        let fingerprint = ConversionQueue.settingsFingerprint(of: configuration)

        // Primary: the central registry.
        if let entry = RipHistoryStore.shared.entry(forIdentity: identity) {
            if entry.settingsFingerprint == fingerprint {
                return entry.outputLocation
            }
            appendToLog("Settings changed since the last rip of \(drive.displayName) — re-ripping.")
            return nil
        }

        // Fallback: legacy per-folder marker (rips made before the registry).
        return legacyCompletedRip(for: drive, mediaType: mediaType, configuration: configuration)
    }

    /// Legacy detection: look for a rip_complete.json in the output directory (and
    /// Plex roots, in case a routed rip predates the registry). Kept for migration
    /// of rips made before the central registry existed.
    private func legacyCompletedRip(for drive: OpticalDrive,
                                    mediaType: MediaRipper.MediaType,
                                    configuration: MediaRipper.RippingConfiguration) -> String? {
        let ripper = MediaRipper()
        let folderName: String
        let mediaTypedRelative: String
        if let plexBase = ripper.plexBaseName(from: configuration) {
            folderName = plexBase
            mediaTypedRelative = plexBase
        } else {
            let movieName = ripper.extractMovieName(from: drive.mountPoint, mediaType: mediaType)
            folderName = movieName
            mediaTypedRelative = "\(mediaType.folderName)/\(movieName)"
        }

        var candidates = [outputPathField.stringValue.appending("/\(mediaTypedRelative)")]
        if settingsManager.contentRoutingEnabled {
            candidates.append(settingsManager.moviesRootDirectory.appending("/\(folderName)"))
            candidates.append(settingsManager.tvShowsRootDirectory.appending("/\(folderName)"))
        }

        for dir in candidates {
            let markerPath = dir.appending("/rip_complete.json")
            guard FileManager.default.fileExists(atPath: markerPath),
                  let contents = try? FileManager.default.contentsOfDirectory(atPath: dir),
                  contents.contains(where: { $0.hasSuffix(".mkv") }) else { continue }

            if let data = try? Data(contentsOf: URL(fileURLWithPath: markerPath)),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let savedSettings = json["settings"] as? [String: String],
               savedSettings != ConversionQueue.settingsFingerprint(of: configuration) {
                appendToLog("Settings changed since the last rip of \(drive.displayName) — re-ripping.")
                return nil
            }
            return dir
        }
        return nil
    }

    /// One-time, first-run prompt offering to set up MakeMKV for Blu-ray. Runs
    /// after the hardware-acceleration check so the two dialogs don't overlap.
    /// DVD ripping needs nothing; this is purely to make Blu-ray work later
    /// without a surprise when the user first inserts a Blu-ray disc.
    func performFirstRunMakeMKVCheck() {
        guard !settingsManager.makemkvFirstRunChecked else { return }
        settingsManager.makemkvFirstRunChecked = true

        // Already installed — clear any Gatekeeper quarantine and confirm it's wired up.
        guard !MakeMKVBackend.isInstalled else {
            if MakeMKVBackend.isQuarantined() {
                MakeMKVBackend.clearQuarantine()
            }
            appendToLog("MakeMKV detected — Blu-ray ripping is ready.")
            return
        }

        let alert = NSAlert()
        alert.messageText = "Set Up Blu-ray Support?"
        alert.informativeText = """
            AutoRip2MKV rips DVDs with no setup. Blu-ray discs use AACS/BD+ \
            protection that needs MakeMKV (free during beta) to decrypt.

            You can set this up now, or skip it — DVD ripping works either way, \
            and you can add Blu-ray support later from Settings.
            """
        alert.alertStyle = .informational
        presentMakeMKVInstallOptions(on: alert, includeSkip: true)
    }

    /// Blu-ray can be ripped if MakeMKV is available (preferred) or the user has
    /// supplied a libaacs key database.
    internal func blurayDecryptionReady() -> Bool {
        if settingsManager.useMakeMKVForBluRay && MakeMKVBackend.isInstalled {
            // MakeMKV isn't notarized; if Gatekeeper has quarantined it, makemkvcon
            // is killed on launch (rips fail with exit 9 / no output). Clear it —
            // xattr is non-privileged, so we can fix this for the user directly.
            if MakeMKVBackend.isQuarantined() {
                appendToLog("MakeMKV is quarantined by macOS Gatekeeper — clearing so it can run...")
                if MakeMKVBackend.clearQuarantine() {
                    appendToLog("Cleared MakeMKV quarantine.")
                } else {
                    appendToLog("Couldn't clear MakeMKV quarantine automatically. "
                        + "Run: xattr -dr com.apple.quarantine /Applications/MakeMKV.app")
                    return false
                }
            }
            // No key on file means MakeMKV is in its 30-day trial (or has an
            // expired one). Don't block — the trial works — just set expectations.
            if !MakeMKVBackend.hasLicenseKey() {
                appendToLog("MakeMKV has no license key yet — running in free trial mode. "
                    + "If MakeMKV asks for a key, AutoRip2MKV will help you get the free beta key.")
            }
            return true
        }
        let keydb = NSString(string: "~/.config/aacs/KEYDB.cfg").expandingTildeInPath
        return FileManager.default.fileExists(atPath: keydb)
    }

    private func showBluRaySetupAlert() {
        let alert = NSAlert()
        alert.messageText = "Blu-ray Ripping Needs MakeMKV"
        alert.informativeText = """
            DVDs rip with no setup, but Blu-ray discs use AACS/BD+ protection that \
            AutoRip2MKV can't decrypt on its own.

            MakeMKV (free during beta) handles Blu-ray decryption, and AutoRip2MKV \
            will use it automatically once it's installed. Advanced users can \
            instead supply a libaacs key database at ~/.config/aacs/KEYDB.cfg.

            The disc has been ejected. Reinsert it after installing MakeMKV.
            """
        alert.alertStyle = .informational
        presentMakeMKVInstallOptions(on: alert, includeSkip: false)
    }

    /// Adds MakeMKV install actions to an alert and runs it. The download page is
    /// the primary (durable) option; Homebrew is offered secondarily and only
    /// while the cask still works — it is deprecated for failing macOS Gatekeeper
    /// and scheduled for removal on 2026-09-01. Index-based dispatch keeps the
    /// branching correct whether or not the Homebrew option is shown.
    private func presentMakeMKVInstallOptions(on alert: NSAlert, includeSkip: Bool) {
        var actions: [() -> Void] = []

        // Primary: the official download page always works.
        alert.addButton(withTitle: "Open Download Page")
        actions.append {
            if let url = URL(string: "https://www.makemkv.com/download/") {
                NSWorkspace.shared.open(url)
            }
        }

        // Secondary: Homebrew, only before the cask's removal date.
        let brewCaskRemovalDate = ISO8601DateFormatter().date(from: "2026-09-01T00:00:00Z") ?? .distantPast
        if let brew = homebrewPath(), Date() < brewCaskRemovalDate {
            alert.addButton(withTitle: "Install with Homebrew")
            actions.append { [weak self] in self?.installMakeMKVWithHomebrew(brewPath: brew) }
        }

        alert.addButton(withTitle: includeSkip ? "Skip for Now" : "Cancel")
        actions.append { }

        let index = alert.runModal().rawValue - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
        if index >= 0 && index < actions.count {
            actions[index]()
        }
    }

    /// Path to the Homebrew binary if installed (Apple Silicon or Intel location).
    private func homebrewPath() -> String? {
        ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]
            .first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    /// Install MakeMKV via `brew install --cask makemkv` in Terminal, so the user
    /// can watch progress and enter their password if prompted. We don't run
    /// privileged installs silently on the user's behalf.
    ///
    /// The cask is deprecated (fails macOS Gatekeeper) and slated for removal on
    /// 2026-09-01; `--no-quarantine` avoids the quarantine flag so the installed
    /// app launches without a Gatekeeper block. After removal, users should use
    /// the download page instead.
    private func installMakeMKVWithHomebrew(brewPath: String) {
        appendToLog("Opening Terminal to install MakeMKV via Homebrew...")
        let command = "\(brewPath) install --cask --no-quarantine makemkv"
        let script = """
            tell application "Terminal"
                activate
                do script "\(command)"
            end tell
            """
        let osa = Process()
        osa.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        osa.arguments = ["-e", script]
        do {
            try osa.run()
            appendToLog("MakeMKV install started in Terminal. Reinsert the disc when it finishes.")
        } catch {
            appendToLog("Couldn't open Terminal automatically. Run: \(command)")
            if let url = URL(string: "https://www.makemkv.com/download/") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    /// Shown when makemkvcon refused to rip for licensing reasons (expired
    /// 30-day trial, expired beta build, or expired/invalid beta key). Offers
    /// the free beta key (fetched from the MakeMKV forum, where the developer
    /// publishes it for this purpose), manual key entry, or purchase.
    func presentMakeMKVRegistrationOptions(detail: String) {
        let alert = NSAlert()
        alert.messageText = "MakeMKV Needs a License Key"
        alert.informativeText = """
            MakeMKV reported: \(detail)

            Blu-ray decryption requires a MakeMKV license key. A lifetime license \
            ($60) never expires and supports MakeMKV's developer, who single-handedly \
            keeps Blu-ray and UHD decryption working. While MakeMKV is in beta, a \
            free key is also published on the forum, but it rotates every couple of \
            months, so you'll need to refresh it periodically.

            DVD ripping is unaffected — this only applies to Blu-ray.
            """
        alert.alertStyle = .warning
        // Buy first so it's the highlighted default — we nudge toward supporting
        // the developer, with the free key still one click away for those who need it.
        alert.addButton(withTitle: "Buy a License")
        alert.addButton(withTitle: "Get Free Beta Key")
        alert.addButton(withTitle: "Enter Key…")
        alert.addButton(withTitle: "Cancel")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            NSWorkspace.shared.open(MakeMKVBackend.purchaseURL)
            appendToLog("Opened the MakeMKV purchase page (\(MakeMKVBackend.purchaseURL.absoluteString)). "
                + "After buying, use Enter Key to register your license.")
        case .alertSecondButtonReturn:
            fetchAndApplyBetaKey()
        case .alertThirdButtonReturn:
            promptForMakeMKVKey()
        default:
            appendToLog("Blu-ray rip needs a MakeMKV key — skipped for now.")
        }
    }

    /// Fetch the current free beta key from the MakeMKV forum, show it to the
    /// user for confirmation, and register it only if they approve. Falls back
    /// to opening the forum thread in the browser if the key can't be found
    /// automatically (layout change, no network).
    private func fetchAndApplyBetaKey() {
        appendToLog("Fetching the current MakeMKV beta key from forum.makemkv.com...")
        MakeMKVBackend.fetchBetaKey { [weak self] key in
            DispatchQueue.main.async {
                guard let self = self else { return }
                guard let key = key else {
                    self.appendToLog("Couldn't find the beta key automatically — opening the forum thread. "
                        + "Copy the key from the first post, then use Enter Key.")
                    NSWorkspace.shared.open(MakeMKVBackend.betaKeyForumURL)
                    self.promptForMakeMKVKey()
                    return
                }
                self.confirmAndApplyBetaKey(key)
            }
        }
    }

    /// Show the fetched beta key and register it only on explicit confirmation,
    /// so the network fetch + `makemkvcon reg` never happen invisibly. The key
    /// is pre-filled but editable, in case the user wants to paste a different
    /// one instead.
    ///
    /// This dialog is also where we encourage buying a license: the free beta
    /// key is generously provided by MakeMKV's developer, and a one-time
    /// purchase both removes the every-couple-of-months key rotation and
    /// supports the work that makes Blu-ray ripping possible at all.
    private func confirmAndApplyBetaKey(_ key: String) {
        let alert = NSAlert()
        alert.messageText = "Register This Free MakeMKV Beta Key?"
        alert.informativeText = """
            Fetched the current free beta key from the MakeMKV forum. Review it \
            below and register it, or cancel.

            This key is provided free by MakeMKV's developer and rotates every \
            couple of months, so you'll need a fresh one periodically. If you rip \
            Blu-rays regularly, please consider buying a lifetime license — it \
            never expires and directly supports the person who single-handedly \
            keeps Blu-ray/UHD decryption working.
            """
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 380, height: 24))
        field.stringValue = key
        alert.accessoryView = field
        alert.addButton(withTitle: "Register Free Key")
        alert.addButton(withTitle: "Buy a License Instead")
        alert.addButton(withTitle: "Cancel")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            let confirmed = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !confirmed.isEmpty else { return }
            applyMakeMKVKey(confirmed, source: "beta key from the MakeMKV forum")
        case .alertSecondButtonReturn:
            NSWorkspace.shared.open(MakeMKVBackend.purchaseURL)
            appendToLog("Opened the MakeMKV purchase page (\(MakeMKVBackend.purchaseURL.absoluteString)). "
                + "After buying, use Enter Key to register your license.")
        default:
            appendToLog("Beta key registration cancelled.")
        }
    }

    /// Modal prompt to paste a MakeMKV key (purchased or copied from the forum).
    /// Offers a direct path to buy a license, so purchasing is always one click
    /// away from the place a key is entered.
    private func promptForMakeMKVKey() {
        let alert = NSAlert()
        alert.messageText = "Enter MakeMKV License Key"
        alert.informativeText = """
            Paste the key (starts with "T-"). It is stored by MakeMKV itself.

            Don't have one? A lifetime license never expires and supports \
            MakeMKV's developer — or grab the current free beta key from the forum.
            """
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 360, height: 24))
        field.placeholderString = "T-..."
        alert.accessoryView = field
        alert.addButton(withTitle: "Register")
        alert.addButton(withTitle: "Buy a License")
        alert.addButton(withTitle: "Cancel")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            let key = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty else { return }
            applyMakeMKVKey(key, source: "entered key")
        case .alertSecondButtonReturn:
            NSWorkspace.shared.open(MakeMKVBackend.purchaseURL)
            appendToLog("Opened the MakeMKV purchase page. Return here with your key to register it.")
        default:
            break
        }
    }

    /// Register a key with makemkvcon and, on success, offer to restart the rip
    /// (the disc is normally still in the drive after a licensing failure).
    private func applyMakeMKVKey(_ key: String, source: String) {
        if MakeMKVBackend.register(key: key) {
            appendToLog("MakeMKV \(source) registered successfully.")
            let alert = NSAlert()
            alert.messageText = "MakeMKV Key Registered"
            alert.informativeText = "Blu-ray ripping is unlocked. Start the rip again now?"
            alert.addButton(withTitle: "Rip Now")
            alert.addButton(withTitle: "Later")
            if alert.runModal() == .alertFirstButtonReturn {
                startRipping()
            }
        } else {
            appendToLog("MakeMKV rejected the \(source). It may have expired — "
                + "check for a newer key or a MakeMKV update.")
            showAlert(title: "Key Not Accepted",
                      message: "MakeMKV rejected the key. Beta keys expire every couple of months — "
                        + "make sure you have the current one, or update MakeMKV itself.")
        }
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
                    // Eject the disc that was just inserted — not whatever the
                    // drive dropdown happens to point at (ejectCurrentDisk uses
                    // the dropdown selection, which may differ).
                    appendToLog("Auto-ejecting \(drive.displayName)...")
                    let devicePath = drive.devicePath
                    let name = drive.displayName
                    DispatchQueue.global(qos: .background).async { [weak self] in
                        let ok = self?.ejectDisk(at: devicePath) ?? false
                        DispatchQueue.main.async {
                            self?.appendToLog(ok
                                ? "\(name) ejected — ready for next disc."
                                : "Failed to eject \(name) — manual ejection may be required.")
                        }
                    }
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

}
