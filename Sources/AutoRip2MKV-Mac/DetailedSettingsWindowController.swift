import Cocoa

class DetailedSettingsWindowController: NSWindowController {

    // MARK: - Properties
    private var settingsManager = SettingsManager.shared

    // MARK: - UI Elements

    // File Storage Section — directory structure (consumed by OutputOrganizer).
    private var fileStorageBox: NSBox!
    private var outputStructurePopup: NSPopUpButton!
    private var movieDirectoryFormatField: NSTextField!
    private var tvShowDirectoryFormatField: NSTextField!

    // Advanced Encoding Section. Note: encoding speed / bitrate control / target
    // bitrate / two-pass / custom-FFmpeg-args and the separate "Quality Presets"
    // box were removed — they were persisted to UserDefaults but never read by any
    // rip, and overlapped the single working "Quality" popup on the Video & Audio
    // box. Only the checkboxes below feed the pipeline. Re-add wired controls here
    // if/when the encode path actually consumes them.
    private var advancedEncodingBox: NSBox!
    private var hardwareAccelerationCheckbox: NSButton!
    private var autoDeinterlaceCheckbox: NSButton!
    private var useMakeMKVCheckbox: NSButton!

    // Output Directory Section (Content Routing only — the output root itself comes
    // from the main window, not here).
    private var outputDirectoryBox: NSBox!
    private var contentRoutingCheckbox: NSButton!
    private var autoRouteCheckbox: NSButton!
    private var moviesRootField: NSTextField!
    private var tvShowsRootField: NSTextField!

    // Quality & Codec Section
    private var qualityBox: NSBox!
    private var videoCodecPopup: NSPopUpButton!
    private var audioCodecPopup: NSPopUpButton!
    private var qualityPopup: NSPopUpButton!
    private var includeSubtitlesCheckbox: NSButton!
    private var includeChaptersCheckbox: NSButton!

    // Advanced Options Section (pre/post-processing scripts — the only Advanced
    // controls with a real effect, run by ScriptRunner).
    private var advancedBox: NSBox!
    private var preProcessingScriptField: NSTextField!
    private var browsePreScriptButton: NSButton!
    private var postProcessingScriptField: NSTextField!
    private var browsePostScriptButton: NSButton!

    // Dialog buttons
    private var okButton: NSButton!
    private var cancelButton: NSButton!
    private var restoreDefaultsButton: NSButton!

    override func windowDidLoad() {
        print("[DEBUG] windowDidLoad called")
        super.windowDidLoad()
        setupWindow()
        setupUI()
        loadCurrentSettings()
        print("[DEBUG] windowDidLoad complete")
    }

    convenience init() {
        print("[DEBUG] DetailedSettingsWindowController init started")
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 900),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Detailed Settings"
        window.center()
        window.minSize = NSSize(width: 600, height: 700)

        print("[DEBUG] Calling self.init(window:)")
        self.init(window: window)
        print("[DEBUG] DetailedSettingsWindowController init complete")
    }

    private func setupWindow() {
        window?.isReleasedWhenClosed = false
        window?.level = NSWindow.Level.normal
    }

    override func showWindow(_ sender: Any?) {
        print("[DEBUG] showWindow called, window: \(String(describing: window))")

        // Manually trigger setup since windowDidLoad isn't being called
        if window?.contentView?.subviews.isEmpty ?? true {
            print("[DEBUG] Window content is empty, setting up UI manually")
            setupWindow()
            setupUI()
            loadCurrentSettings()
        }

        super.showWindow(sender)
        print("[DEBUG] showWindow complete")
    }

    private func setupUI() {
        guard let contentView = window?.contentView else { return }

        setupContentView(contentView)

        // Tabbed layout: each tab is its own scrolling section list, so the
        // settings are grouped instead of one long scroll. Sections are the same
        // NSBox builders as before — only which tab's stack they're added to changes.
        let tabView = NSTabView()
        tabView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(tabView)

        // Organization and Naming tabs were removed: their controls (bonus-content,
        // file-name templates, series/season dirs, auto-rename, etc.) were never
        // consumed by the pipeline. The one part with a real effect — the output
        // directory structure — lives in the File Storage section here, wired
        // through OutputOrganizer. See SETTINGS_AUDIT.md.
        addTab(to: tabView, label: "Output & Routing") { stack in
            self.setupOutputDirectorySection(in: stack)
            self.setupFileStorageSection(in: stack)
        }
        addTab(to: tabView, label: "Encoding") { stack in
            self.setupQualitySection(in: stack)
            self.setupAdvancedEncodingSection(in: stack)
        }
        addTab(to: tabView, label: "Advanced") { stack in
            self.setupAdvancedSection(in: stack)
        }

        setupDialogButtons(in: contentView)

        NSLayoutConstraint.activate([
            tabView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            tabView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            tabView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            tabView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -60),
        ])
    }

    /// Add a tab whose content is a vertical scroll of section boxes. `build`
    /// receives the tab's stack view and adds the same section boxes as before.
    private func addTab(to tabView: NSTabView, label: String,
                        build: (NSStackView) -> Void) {
        let item = NSTabViewItem(identifier: label)
        item.label = label

        // A flipped document view so content lays out top-down and its height is
        // driven by the pinned stack — this is what keeps non-selected tabs from
        // rendering empty (NSTabView lays those out lazily, so their content
        // height must be fully constraint-defined, not dependent on a layout pass
        // that only happens for the visible tab).
        let documentView = FlippedView()
        documentView.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 16
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        documentView.addSubview(stack)

        build(stack)

        // Make each section box span the tab width, and ensure its contentView is
        // pinned so the box self-sizes. Some sections build with `box.contentView =
        // stack` (which does NOT auto-pin when the box uses autolayout), so those
        // boxes collapsed to zero height on lazily-laid-out tabs and rendered blank.
        // Pinning here fixes every such section in one place.
        for case let box as NSBox in stack.arrangedSubviews {
            box.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
            if let cv = box.contentView, cv.superview === box {
                cv.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    cv.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 8),
                    cv.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -8),
                    cv.topAnchor.constraint(equalTo: box.topAnchor, constant: 24),
                    cv.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -8),
                ])
            }
        }

        // Left-justify everything: the per-section inner stacks default to
        // center-X alignment (which made checkboxes and rows float in the middle).
        // Force leading alignment throughout for a clean left-aligned column.
        leftAlignStacks(in: stack)

        // Use the scrollView itself as the tab's view. NSTabView stretches
        // item.view to fill the tab's content rect, so the scroll gets full
        // height — a wrapper NSView does NOT get auto-stretched and collapsed to
        // zero height (which was blanking every non-initial tab).
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = true
        scrollView.autoresizingMask = [.width, .height]
        scrollView.drawsBackground = false
        scrollView.documentView = documentView

        NSLayoutConstraint.activate([
            // Document view matches the scroll's width; its height grows with the
            // stack (all four stack edges pinned → explicit content height).
            documentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            stack.topAnchor.constraint(equalTo: documentView.topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: documentView.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: documentView.trailingAnchor, constant: -12),
            stack.bottomAnchor.constraint(equalTo: documentView.bottomAnchor, constant: -12),
        ])

        item.view = scrollView
        tabView.addTabViewItem(item)
    }
    
    private func setupContentView(_ contentView: NSView) {
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
    }

    /// Recursively set every vertical NSStackView to leading (left) alignment, so
    /// section content is left-justified instead of floating center.
    private func leftAlignStacks(in view: NSView) {
        if let stack = view as? NSStackView, stack.orientation == .vertical {
            stack.alignment = .leading
        }
        for sub in view.subviews { leftAlignStacks(in: sub) }
        // NSBox content lives in its contentView, which may not be in `subviews`.
        if let box = view as? NSBox, let cv = box.contentView {
            leftAlignStacks(in: cv)
        }
    }
    
    // MARK: - New Settings Sections


    private func setupAdvancedEncodingSection(in stackView: NSStackView) {
        advancedEncodingBox = NSBox()
        advancedEncodingBox.title = "Advanced Encoding Settings"
        advancedEncodingBox.titlePosition = .atTop
        advancedEncodingBox.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(advancedEncodingBox)

        let sectionStackView = NSStackView()
        sectionStackView.orientation = .vertical
        sectionStackView.spacing = 8
        sectionStackView.translatesAutoresizingMaskIntoConstraints = false
        advancedEncodingBox.addSubview(sectionStackView)

        // Only controls the rip pipeline actually reads live here. (Encoding speed,
        // bitrate control, target bitrate, two-pass, and custom FFmpeg args were
        // removed — they were never consumed and duplicated the "Quality" popup.)
        hardwareAccelerationCheckbox = NSButton(
            checkboxWithTitle: "Enable hardware acceleration (when available)",
            target: self,
            action: nil
        )
        hardwareAccelerationCheckbox.state = .off
        autoDeinterlaceCheckbox = NSButton(
            checkboxWithTitle: "Auto-deinterlace interlaced video (recommended)",
            target: self,
            action: nil
        )
        autoDeinterlaceCheckbox.state = .on

        sectionStackView.addArrangedSubview(hardwareAccelerationCheckbox)
        sectionStackView.addArrangedSubview(autoDeinterlaceCheckbox)

        useMakeMKVCheckbox = NSButton(
            checkboxWithTitle: "Use MakeMKV for Blu-ray (recommended; requires MakeMKV installed)",
            target: self,
            action: nil
        )
        useMakeMKVCheckbox.state = .on
        sectionStackView.addArrangedSubview(useMakeMKVCheckbox)

        NSLayoutConstraint.activate([
            sectionStackView.topAnchor.constraint(equalTo: advancedEncodingBox.topAnchor, constant: 25),
            sectionStackView.leadingAnchor.constraint(equalTo: advancedEncodingBox.leadingAnchor, constant: 10),
            sectionStackView.trailingAnchor.constraint(equalTo: advancedEncodingBox.trailingAnchor, constant: -10),
            sectionStackView.bottomAnchor.constraint(equalTo: advancedEncodingBox.bottomAnchor, constant: -10)
        ])
    }

    private func setupOutputDirectorySection(in stackView: NSStackView) {
        outputDirectoryBox = NSBox()
        outputDirectoryBox.title = "Output Directory Preferences"
        outputDirectoryBox.titlePosition = .atTop
        outputDirectoryBox.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(outputDirectoryBox)

        let sectionStackView = NSStackView()
        sectionStackView.orientation = .vertical
        sectionStackView.spacing = 8
        sectionStackView.translatesAutoresizingMaskIntoConstraints = false
        outputDirectoryBox.addSubview(sectionStackView)

        // (Default Output Directory / date-subdirectories / output-path-template
        // controls were removed — never consumed; the real output root comes from
        // the main window, and directory structure lives in File Storage below.)

        // --- Content Routing: sort finished rips into Movies / TV Shows roots ---
        let routingHeader = NSTextField(labelWithString: "Content Routing (Plex libraries):")
        routingHeader.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
        sectionStackView.addArrangedSubview(routingHeader)

        contentRoutingCheckbox = NSButton(
            checkboxWithTitle: "Sort rips into Movies / TV Shows folders by content",
            target: self, action: nil)
        sectionStackView.addArrangedSubview(contentRoutingCheckbox)

        autoRouteCheckbox = NSButton(
            checkboxWithTitle: "Auto-route confident guesses (only ambiguous rips wait for review)",
            target: self, action: nil)
        sectionStackView.addArrangedSubview(autoRouteCheckbox)

        let moviesLabel = NSTextField(labelWithString: "Movies Folder:")
        moviesRootField = NSTextField()
        moviesRootField.placeholderString = "~/Plex/Movies"
        let moviesBrowse = NSButton(title: "Browse...", target: self,
                                    action: #selector(browseForMoviesRoot))
        sectionStackView.addArrangedSubview(
            createLabelControlButtonRow(label: moviesLabel, control: moviesRootField, button: moviesBrowse))

        let tvLabel = NSTextField(labelWithString: "TV Shows Folder:")
        tvShowsRootField = NSTextField()
        tvShowsRootField.placeholderString = "~/Plex/TVShows"
        let tvBrowse = NSButton(title: "Browse...", target: self,
                                action: #selector(browseForTVShowsRoot))
        sectionStackView.addArrangedSubview(
            createLabelControlButtonRow(label: tvLabel, control: tvShowsRootField, button: tvBrowse))

        NSLayoutConstraint.activate([
            sectionStackView.topAnchor.constraint(equalTo: outputDirectoryBox.topAnchor, constant: 25),
            sectionStackView.leadingAnchor.constraint(equalTo: outputDirectoryBox.leadingAnchor, constant: 10),
            sectionStackView.trailingAnchor.constraint(equalTo: outputDirectoryBox.trailingAnchor, constant: -10),
            sectionStackView.bottomAnchor.constraint(equalTo: outputDirectoryBox.bottomAnchor, constant: -10)
        ])
    }

    @objc private func browseForMoviesRoot() {
        browseForFolder(into: moviesRootField)
    }

    @objc private func browseForTVShowsRoot() {
        browseForFolder(into: tvShowsRootField)
    }

    private func browseForFolder(into field: NSTextField) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            field.stringValue = url.path
        }
    }

    private func setupFileStorageSection(in stackView: NSStackView) {
        fileStorageBox = NSBox()
        fileStorageBox.title = "File Storage & Organization"
        fileStorageBox.titlePosition = .atTop
        fileStorageBox.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(fileStorageBox)

        let sectionStackView = NSStackView()
        sectionStackView.orientation = .vertical
        sectionStackView.spacing = 8
        sectionStackView.translatesAutoresizingMaskIntoConstraints = false
        fileStorageBox.addSubview(sectionStackView)

        // Output structure
        let outputStructureLabel = NSTextField(labelWithString: "Directory Structure:")
        outputStructurePopup = NSPopUpButton()
        outputStructurePopup.addItems(withTitles: [
            "Flat - All files in output directory",
            "By Media Type - Movies/TV Shows separated",
            "By Year - Organized by release year",
            "By Genre - Organized by genre (when available)",
            "Custom - Use format strings below"
        ])
        outputStructurePopup.selectItem(at: 1) // Default to "By Media Type"

        let outputRow = createLabelControlRow(label: outputStructureLabel, control: outputStructurePopup)
        sectionStackView.addArrangedSubview(outputRow)

        // Custom-structure templates (used only when "Custom" is selected above).
        // Only {title} and {year} resolve — the ripper doesn't know season/episode/
        // genre — so a segment referencing another token is dropped at rip time.
        let customHint = NSTextField(labelWithString: "Custom templates support {title} and {year}.")
        customHint.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        customHint.textColor = .secondaryLabelColor
        sectionStackView.addArrangedSubview(customHint)

        let movieFormatLabel = NSTextField(labelWithString: "Movie Directory Format:")
        movieDirectoryFormatField = NSTextField()
        movieDirectoryFormatField.placeholderString = "Movies/{title} ({year})"
        movieDirectoryFormatField.stringValue = "Movies/{title} ({year})"

        let movieFormatRow = createLabelControlRow(label: movieFormatLabel, control: movieDirectoryFormatField)
        sectionStackView.addArrangedSubview(movieFormatRow)

        let tvFormatLabel = NSTextField(labelWithString: "TV Show Directory Format:")
        tvShowDirectoryFormatField = NSTextField()
        tvShowDirectoryFormatField.placeholderString = "TV Shows/{series}"
        tvShowDirectoryFormatField.stringValue = "TV Shows/{series}"

        let tvFormatRow = createLabelControlRow(label: tvFormatLabel, control: tvShowDirectoryFormatField)
        sectionStackView.addArrangedSubview(tvFormatRow)

        NSLayoutConstraint.activate([
            sectionStackView.topAnchor.constraint(equalTo: fileStorageBox.topAnchor, constant: 25),
            sectionStackView.leadingAnchor.constraint(equalTo: fileStorageBox.leadingAnchor, constant: 10),
            sectionStackView.trailingAnchor.constraint(equalTo: fileStorageBox.trailingAnchor, constant: -10),
            sectionStackView.bottomAnchor.constraint(equalTo: fileStorageBox.bottomAnchor, constant: -10)
        ])
    }

    private func setupQualitySection(in stackView: NSStackView) {
        qualityBox = NSBox()
        qualityBox.title = "Quality & Codecs"
        qualityBox.titlePosition = .atTop
        qualityBox.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(qualityBox)

        let sectionStackView = NSStackView()
        sectionStackView.orientation = .vertical
        sectionStackView.spacing = 8
        sectionStackView.translatesAutoresizingMaskIntoConstraints = false
        qualityBox.addSubview(sectionStackView)

        // Codec selection
        let videoCodecLabel = NSTextField(labelWithString: "Video Codec:")
        videoCodecPopup = NSPopUpButton()
        videoCodecPopup.addItems(withTitles: ["H.264 (x264)", "H.265 (x265/HEVC)", "VP9", "AV1"])
        videoCodecPopup.selectItem(at: 0) // Default to H.264

        let videoCodecRow = createLabelControlRow(label: videoCodecLabel, control: videoCodecPopup)
        sectionStackView.addArrangedSubview(videoCodecRow)

        let audioCodecLabel = NSTextField(labelWithString: "Audio Codec:")
        audioCodecPopup = NSPopUpButton()
        audioCodecPopup.addItems(withTitles: ["AAC", "AC3 (Dolby Digital)", "DTS", "FLAC"])
        audioCodecPopup.selectItem(at: 0) // Default to AAC

        let audioCodecRow = createLabelControlRow(label: audioCodecLabel, control: audioCodecPopup)
        sectionStackView.addArrangedSubview(audioCodecRow)

        let qualityLabel = NSTextField(labelWithString: "Quality:")
        qualityPopup = NSPopUpButton()
        qualityPopup.addItems(withTitles: ["Low (Fast)", "Medium (Balanced)", "High (Best Quality)", "Lossless"])
        qualityPopup.selectItem(at: 2) // Default to High

        let qualityRow = createLabelControlRow(label: qualityLabel, control: qualityPopup)
        sectionStackView.addArrangedSubview(qualityRow)

        // Content options
        includeSubtitlesCheckbox = NSButton(checkboxWithTitle: "Include subtitles", target: self, action: nil)
        includeChaptersCheckbox = NSButton(checkboxWithTitle: "Include chapter markers", target: self, action: nil)

        sectionStackView.addArrangedSubview(includeSubtitlesCheckbox)
        sectionStackView.addArrangedSubview(includeChaptersCheckbox)
        // (Preferred Language popup removed — it was never persisted or consumed.)

        NSLayoutConstraint.activate([
            sectionStackView.topAnchor.constraint(equalTo: qualityBox.topAnchor, constant: 25),
            sectionStackView.leadingAnchor.constraint(equalTo: qualityBox.leadingAnchor, constant: 10),
            sectionStackView.trailingAnchor.constraint(equalTo: qualityBox.trailingAnchor, constant: -10),
            sectionStackView.bottomAnchor.constraint(equalTo: qualityBox.bottomAnchor, constant: -10)
        ])
    }

    private func setupAdvancedSection(in stackView: NSStackView) {
        advancedBox = NSBox()
        advancedBox.title = "Advanced Options"
        advancedBox.titlePosition = .atTop
        advancedBox.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(advancedBox)

        let sectionStackView = NSStackView()
        sectionStackView.orientation = .vertical
        sectionStackView.spacing = 8
        sectionStackView.translatesAutoresizingMaskIntoConstraints = false
        advancedBox.addSubview(sectionStackView)

        // (Preserve-timestamps / create-backup / auto-retry / max-retries controls
        // were removed — none were consumed; the rippers have their own fixed retry
        // behavior. The pre/post-processing scripts below ARE run, by ScriptRunner.)
        let preScriptLabel = NSTextField(labelWithString: "Pre-processing Script:")
        preProcessingScriptField = NSTextField()
        preProcessingScriptField.placeholderString = "Path to script to run before ripping..."
        browsePreScriptButton = NSButton(title: "Browse...", target: self, action: #selector(browseForPreScript))

        let preScriptRow = createLabelControlButtonRow(label: preScriptLabel, control: preProcessingScriptField, button: browsePreScriptButton)
        sectionStackView.addArrangedSubview(preScriptRow)

        let scriptLabel = NSTextField(labelWithString: "Post-processing Script:")
        postProcessingScriptField = NSTextField()
        postProcessingScriptField.placeholderString = "Path to script to run after ripping..."
        browsePostScriptButton = NSButton(title: "Browse...", target: self, action: #selector(browseForPostScript))

        let scriptRow = createLabelControlButtonRow(label: scriptLabel, control: postProcessingScriptField, button: browsePostScriptButton)
        sectionStackView.addArrangedSubview(scriptRow)

        NSLayoutConstraint.activate([
            sectionStackView.topAnchor.constraint(equalTo: advancedBox.topAnchor, constant: 25),
            sectionStackView.leadingAnchor.constraint(equalTo: advancedBox.leadingAnchor, constant: 10),
            sectionStackView.trailingAnchor.constraint(equalTo: advancedBox.trailingAnchor, constant: -10),
            sectionStackView.bottomAnchor.constraint(equalTo: advancedBox.bottomAnchor, constant: -10)
        ])
    }

    private func setupDialogButtons(in contentView: NSView) {
        let buttonStackView = NSStackView()
        buttonStackView.orientation = .horizontal
        buttonStackView.spacing = 12
        buttonStackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(buttonStackView)

        restoreDefaultsButton = NSButton(title: "Restore Defaults", target: self, action: #selector(restoreDefaults))
        cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancelSettings))
        okButton = NSButton(title: "OK", target: self, action: #selector(applySettings))

        okButton.keyEquivalent = "\r"
        cancelButton.keyEquivalent = "\u{1b}"

        buttonStackView.addArrangedSubview(restoreDefaultsButton)
        buttonStackView.addArrangedSubview(NSView()) // Spacer
        buttonStackView.addArrangedSubview(cancelButton)
        buttonStackView.addArrangedSubview(okButton)

        NSLayoutConstraint.activate([
            buttonStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            buttonStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            buttonStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            buttonStackView.heightAnchor.constraint(equalToConstant: 32)
        ])
    }

    // MARK: - Helper Methods

    private func createLabelControlRow(label: NSTextField, control: NSControl) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        label.translatesAutoresizingMaskIntoConstraints = false
        label.alignment = .left
        control.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(label)
        container.addSubview(control)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            label.widthAnchor.constraint(equalToConstant: 180),

            control.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 10),
            control.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            control.centerYAnchor.constraint(equalTo: container.centerYAnchor),

            container.heightAnchor.constraint(equalToConstant: 32)
        ])

        return container
    }

    private func createLabelControlButtonRow(
        label: NSTextField,
        control: NSControl,
        button: NSButton
    ) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        label.translatesAutoresizingMaskIntoConstraints = false
        control.translatesAutoresizingMaskIntoConstraints = false
        button.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(label)
        container.addSubview(control)
        container.addSubview(button)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            label.widthAnchor.constraint(equalToConstant: 200),

            control.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 10),
            control.trailingAnchor.constraint(equalTo: button.leadingAnchor, constant: -10),
            control.centerYAnchor.constraint(equalTo: container.centerYAnchor),

            button.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            button.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            button.widthAnchor.constraint(equalToConstant: 100),

            container.heightAnchor.constraint(equalToConstant: 32)
        ])

        return container
    }

    // MARK: - Settings Management

    private func loadCurrentSettings() {
        // Load existing settings from SettingsManager
        videoCodecPopup.selectItem(withTitle: settingsManager.videoCodec == "h265" ? "H.265 (x265/HEVC)" : "H.264 (x264)")
        audioCodecPopup.selectItem(withTitle: settingsManager.audioCodec == "ac3" ? "AC3 (Dolby Digital)" : "AAC")

        switch settingsManager.quality {
        case "low":
            qualityPopup.selectItem(at: 0)
        case "medium":
            qualityPopup.selectItem(at: 1)
        case "high":
            qualityPopup.selectItem(at: 2)
        default:
            qualityPopup.selectItem(at: 2)
        }

        includeSubtitlesCheckbox.state = settingsManager.includeSubtitles ? .on : .off
        includeChaptersCheckbox.state = settingsManager.includeChapters ? .on : .off

        // Load extended settings
        loadExtendedSettings()

        print("[DEBUG] Settings loaded: video=\(settingsManager.videoCodec), audio=\(settingsManager.audioCodec), quality=\(settingsManager.quality)")
    }

    private func loadExtendedSettings() {
        let defaults = UserDefaults.standard

        // Advanced Encoding (wired-up checkboxes).
        hardwareAccelerationCheckbox.state = settingsManager.hardwareAcceleration ? .on : .off
        autoDeinterlaceCheckbox.state = settingsManager.autoDeinterlace ? .on : .off
        useMakeMKVCheckbox.state = settingsManager.useMakeMKVForBluRay ? .on : .off

        // Content Routing.
        contentRoutingCheckbox.state = settingsManager.contentRoutingEnabled ? .on : .off
        autoRouteCheckbox.state = settingsManager.autoRouteHighConfidence ? .on : .off
        moviesRootField.stringValue = settingsManager.moviesRootDirectory
        tvShowsRootField.stringValue = settingsManager.tvShowsRootDirectory

        // Directory structure (consumed by OutputOrganizer).
        outputStructurePopup.selectItem(at: settingsManager.outputStructureType)
        movieDirectoryFormatField.stringValue = settingsManager.movieDirectoryFormat
        tvShowDirectoryFormatField.stringValue = settingsManager.tvShowDirectoryFormat

        // Advanced scripts (run by ScriptRunner).
        if let preScriptPath = defaults.string(forKey: "preProcessingScript") {
            preProcessingScriptField.stringValue = preScriptPath
        }
        if let postScriptPath = defaults.string(forKey: "postProcessingScript") {
            postProcessingScriptField.stringValue = postScriptPath
        }
    }

    // MARK: - Actions

    @objc private func browseForPreScript() {
        if let url = openScriptPanel(title: "Select Pre-processing Script") {
            preProcessingScriptField.stringValue = url.path
        }
    }

    @objc private func browseForPostScript() {
        if let url = openScriptPanel(title: "Select Post-processing Script") {
            postProcessingScriptField.stringValue = url.path
        }
    }

    private func openScriptPanel(title: String) -> URL? {
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        if #available(macOS 12.0, *) {
            openPanel.allowedContentTypes = [.shellScript, .pythonScript, .rubyScript, .perlScript, .javaScript]
        } else {
            openPanel.allowedFileTypes = ["sh", "py", "rb", "pl", "js"]
        }
        openPanel.title = title

        if openPanel.runModal() == .OK {
            return openPanel.url
        }
        return nil
    }

    @objc private func restoreDefaults() {
        // Advanced Encoding (wired-up checkboxes).
        hardwareAccelerationCheckbox.state = .off
        autoDeinterlaceCheckbox.state = .on
        useMakeMKVCheckbox.state = .on

        // Directory structure.
        outputStructurePopup.selectItem(at: 1) // By Media Type
        movieDirectoryFormatField.stringValue = "Movies/{title} ({year})"
        tvShowDirectoryFormatField.stringValue = "TV Shows/{series}"

        // Quality & codecs.
        videoCodecPopup.selectItem(at: 0) // H.264
        audioCodecPopup.selectItem(at: 0) // AAC
        qualityPopup.selectItem(at: 2) // High
        includeSubtitlesCheckbox.state = .on
        includeChaptersCheckbox.state = .on

        // Content routing.
        contentRoutingCheckbox.state = .off
        autoRouteCheckbox.state = .off

        // Advanced scripts.
        preProcessingScriptField.stringValue = ""
        postProcessingScriptField.stringValue = ""
    }

    @objc private func cancelSettings() {
        window?.close()
    }

    @objc private func applySettings() {
        saveSettings()
        window?.close()
    }

    private func saveSettings() {
        // Save basic settings to SettingsManager
        settingsManager.videoCodec = videoCodecPopup.titleOfSelectedItem == "H.265 (x265/HEVC)" ? "h265" : "h264"
        settingsManager.audioCodec = audioCodecPopup.titleOfSelectedItem == "AC3 (Dolby Digital)" ? "ac3" : "aac"

        switch qualityPopup.indexOfSelectedItem {
        case 0:
            settingsManager.quality = "low"
        case 1:
            settingsManager.quality = "medium"
        case 2:
            settingsManager.quality = "high"
        default:
            settingsManager.quality = "high"
        }

        settingsManager.includeSubtitles = includeSubtitlesCheckbox.state == .on
        settingsManager.includeChapters = includeChaptersCheckbox.state == .on

        // Save extended settings
        saveExtendedSettings()

        print("[DEBUG] Settings saved: video=\(settingsManager.videoCodec), audio=\(settingsManager.audioCodec), quality=\(settingsManager.quality)")
    }

    private func saveExtendedSettings() {
        let defaults = UserDefaults.standard

        // Advanced Encoding (wired-up checkboxes).
        settingsManager.hardwareAcceleration = hardwareAccelerationCheckbox.state == .on
        settingsManager.autoDeinterlace = autoDeinterlaceCheckbox.state == .on
        settingsManager.useMakeMKVForBluRay = useMakeMKVCheckbox.state == .on

        // Content Routing.
        settingsManager.contentRoutingEnabled = contentRoutingCheckbox.state == .on
        settingsManager.autoRouteHighConfidence = autoRouteCheckbox.state == .on
        if !moviesRootField.stringValue.isEmpty {
            settingsManager.moviesRootDirectory =
                NSString(string: moviesRootField.stringValue).expandingTildeInPath
        }
        if !tvShowsRootField.stringValue.isEmpty {
            settingsManager.tvShowsRootDirectory =
                NSString(string: tvShowsRootField.stringValue).expandingTildeInPath
        }

        // Directory structure (consumed by OutputOrganizer).
        settingsManager.outputStructureType = outputStructurePopup.indexOfSelectedItem
        settingsManager.movieDirectoryFormat = movieDirectoryFormatField.stringValue
        settingsManager.tvShowDirectoryFormat = tvShowDirectoryFormatField.stringValue

        // Advanced scripts (run by ScriptRunner).
        defaults.set(preProcessingScriptField.stringValue, forKey: "preProcessingScript")
        defaults.set(postProcessingScriptField.stringValue, forKey: "postProcessingScript")

        defaults.synchronize()
    }
}

/// A top-down document view for scroll views, so content starts at the top and
/// grows downward (AppKit's default is bottom-left origin).
private final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}
