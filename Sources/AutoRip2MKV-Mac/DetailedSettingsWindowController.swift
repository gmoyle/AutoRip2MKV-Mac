import Cocoa

class DetailedSettingsWindowController: NSWindowController {

    // MARK: - Properties
    private var settingsManager = SettingsManager.shared

    // MARK: - UI Elements

    // File Storage Section
    private var fileStorageBox: NSBox!
    private var outputStructurePopup: NSPopUpButton!
    private var createSeriesDirectoryCheckbox: NSButton!
    private var createSeasonDirectoryCheckbox: NSButton!
    private var movieDirectoryFormatField: NSTextField!
    private var tvShowDirectoryFormatField: NSTextField!

    // Bonus Content Section
    private var bonusContentBox: NSBox!
    private var includeBonusFeaturesCheckbox: NSButton!
    private var includeCommentariesCheckbox: NSButton!
    private var includeDeletedScenesCheckbox: NSButton!
    private var includeMakingOfCheckbox: NSButton!
    private var includeTrailersCheckbox: NSButton!
    private var bonusContentStructurePopup: NSPopUpButton!
    private var bonusContentDirectoryField: NSTextField!

    // File Organization Section (NEW)
    var fileOrganizationBox: NSBox!
    var autoRenameFilesCheckbox: NSButton!
    var createYearDirectoriesCheckbox: NSButton!
    var createGenreDirectoriesCheckbox: NSButton!
    var duplicateHandlingPopup: NSPopUpButton!
    var minimumFileSizeField: NSTextField!

    // Advanced Encoding Section (NEW)
    private var advancedEncodingBox: NSBox!
    private var encodingSpeedPopup: NSPopUpButton!
    private var bitrateControlPopup: NSPopUpButton!
    private var targetBitrateField: NSTextField!
    private var twoPassEncodingCheckbox: NSButton!
    private var hardwareAccelerationCheckbox: NSButton!
    private var customFFmpegArgsField: NSTextField!

    // Output Directory Section (NEW)
    private var outputDirectoryBox: NSBox!
    private var defaultOutputPathField: NSTextField!
    private var browseOutputButton: NSButton!
    private var createDateDirectoriesCheckbox: NSButton!
    private var outputPathTemplateField: NSTextField!

    // Quality Presets Section (NEW)
    private var qualityPresetsBox: NSBox!
    private var presetPopup: NSPopUpButton!
    private var customPresetNameField: NSTextField!
    private var savePresetButton: NSButton!
    private var deletePresetButton: NSButton!

    // File Naming Section
    private var fileNamingBox: NSBox!
    private var movieFileFormatField: NSTextField!
    private var tvShowFileFormatField: NSTextField!
    private var seasonEpisodeFormatField: NSTextField!
    private var includeYearInFilenameCheckbox: NSButton!
    private var includeResolutionInFilenameCheckbox: NSButton!
    private var includeCodecInFilenameCheckbox: NSButton!

    // Quality & Codec Section
    private var qualityBox: NSBox!
    private var videoCodecPopup: NSPopUpButton!
    private var audioCodecPopup: NSPopUpButton!
    private var qualityPopup: NSPopUpButton!
    private var includeSubtitlesCheckbox: NSButton!
    private var includeChaptersCheckbox: NSButton!
    private var preferredLanguagePopup: NSPopUpButton!

    // Advanced Options Section
    private var advancedBox: NSBox!
    private var preserveOriginalTimestampsCheckbox: NSButton!
    private var createBackupsCheckbox: NSButton!
    private var autoRetryOnFailureCheckbox: NSButton!
    private var maxRetryAttemptsField: NSTextField!
    private var postProcessingScriptField: NSTextField!
    private var browseScriptButton: NSButton!

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
        let scrollView = createScrollView(in: contentView)
        let mainStackView = createMainStackView(in: scrollView)
        let titleLabel = createTitleLabel(in: mainStackView)
        
        setupAllSections(in: mainStackView)
        configureWidthConstraints(for: mainStackView, excluding: titleLabel)
        setupDialogButtons(in: contentView)
        setupLayoutConstraints(
            scrollView: scrollView,
            mainStackView: mainStackView,
            titleLabel: titleLabel,
            contentView: contentView
        )
    }
    
    private func setupContentView(_ contentView: NSView) {
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
    }
    
    private func createScrollView(in contentView: NSView) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(scrollView)
        return scrollView
    }
    
    private func createMainStackView(in scrollView: NSScrollView) -> NSStackView {
        let mainStackView = NSStackView()
        mainStackView.orientation = .vertical
        mainStackView.spacing = 20
        mainStackView.alignment = .leading
        mainStackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = mainStackView
        return mainStackView
    }
    
    private func createTitleLabel(in mainStackView: NSStackView) -> NSTextField {
        let titleLabel = NSTextField(labelWithString: "AutoRip2MKV Detailed Settings")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 18)
        titleLabel.alignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        mainStackView.addArrangedSubview(titleLabel)
        return titleLabel
    }
    
    private func setupAllSections(in mainStackView: NSStackView) {
        setupFileOrganizationSection(in: mainStackView)
        setupAdvancedEncodingSection(in: mainStackView)
        setupOutputDirectorySection(in: mainStackView)
        setupQualityPresetsSection(in: mainStackView)
        setupFileStorageSection(in: mainStackView)
        setupBonusContentSection(in: mainStackView)
        setupFileNamingSection(in: mainStackView)
        setupQualitySection(in: mainStackView)
        setupAdvancedSection(in: mainStackView)
    }
    
    private func configureWidthConstraints(for mainStackView: NSStackView, excluding titleLabel: NSTextField) {
        for arrangedSubview in mainStackView.arrangedSubviews {
            if arrangedSubview != titleLabel {
                arrangedSubview.widthAnchor.constraint(
                    equalTo: mainStackView.widthAnchor,
                    constant: -40
                ).isActive = true
            }
        }
    }
    
    private func setupLayoutConstraints(
        scrollView: NSScrollView,
        mainStackView: NSStackView,
        titleLabel: NSTextField,
        contentView: NSView
    ) {
        NSLayoutConstraint.activate([
            // Title width constraint
            titleLabel.widthAnchor.constraint(equalTo: mainStackView.widthAnchor),

            // Scroll view
            scrollView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            scrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -70),

            // Main stack view
            mainStackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            mainStackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            mainStackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            mainStackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
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

        // Encoding speed
        let speedLabel = NSTextField(labelWithString: "Encoding Speed:")
        encodingSpeedPopup = NSPopUpButton()
        encodingSpeedPopup.addItems(withTitles: [
            "Ultra Fast (lowest quality)",
            "Very Fast",
            "Fast",
            "Medium (balanced)",
            "Slow (better quality)",
            "Very Slow (highest quality)"
        ])
        encodingSpeedPopup.selectItem(at: 3) // Default to Medium

        let speedRow = createLabelControlRow(label: speedLabel, control: encodingSpeedPopup)
        sectionStackView.addArrangedSubview(speedRow)

        // Bitrate control
        let bitrateControlLabel = NSTextField(labelWithString: "Bitrate Control:")
        bitrateControlPopup = NSPopUpButton()
        bitrateControlPopup.addItems(withTitles: [
            "Constant Quality (CRF)",
            "Target Bitrate (CBR)",
            "Variable Bitrate (VBR)",
            "Constrained VBR"
        ])
        bitrateControlPopup.selectItem(at: 0) // Default to CRF

        let bitrateControlRow = createLabelControlRow(label: bitrateControlLabel, control: bitrateControlPopup)
        sectionStackView.addArrangedSubview(bitrateControlRow)

        // Target bitrate
        let targetBitrateLabel = NSTextField(labelWithString: "Target Bitrate (Mbps):")
        targetBitrateField = NSTextField()
        targetBitrateField.stringValue = "5.0"
        targetBitrateField.placeholderString = "5.0"

        let targetBitrateRow = createLabelControlRow(label: targetBitrateLabel, control: targetBitrateField)
        sectionStackView.addArrangedSubview(targetBitrateRow)

        // Encoding options
        twoPassEncodingCheckbox = NSButton(checkboxWithTitle: "Use two-pass encoding (slower, better quality)", target: self, action: nil)
        hardwareAccelerationCheckbox = NSButton(
            checkboxWithTitle: "Enable hardware acceleration (when available)",
            target: self,
            action: nil
        )
        hardwareAccelerationCheckbox.state = .off

        sectionStackView.addArrangedSubview(twoPassEncodingCheckbox)
        sectionStackView.addArrangedSubview(hardwareAccelerationCheckbox)

        // Custom FFmpeg arguments
        let customArgsLabel = NSTextField(labelWithString: "Custom FFmpeg Arguments:")
        customFFmpegArgsField = NSTextField()
        customFFmpegArgsField.placeholderString = "Additional FFmpeg command line arguments..."

        let customArgsRow = createLabelControlRow(label: customArgsLabel, control: customFFmpegArgsField)
        sectionStackView.addArrangedSubview(customArgsRow)

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

        // Default output path
        let defaultPathLabel = NSTextField(labelWithString: "Default Output Directory:")
        defaultOutputPathField = NSTextField()
        defaultOutputPathField.placeholderString = "~/Movies/Ripped"
        defaultOutputPathField.stringValue = "~/Movies/Ripped"
        browseOutputButton = NSButton(title: "Browse...", target: self, action: #selector(browseForOutputDirectory))

        let pathRow = createLabelControlButtonRow(label: defaultPathLabel, control: defaultOutputPathField, button: browseOutputButton)
        sectionStackView.addArrangedSubview(pathRow)

        // Create date directories
        createDateDirectoriesCheckbox = NSButton(checkboxWithTitle: "Create date-based subdirectories (YYYY-MM-DD)", target: self, action: nil)
        sectionStackView.addArrangedSubview(createDateDirectoriesCheckbox)

        // Output path template
        let templateLabel = NSTextField(labelWithString: "Output Path Template:")
        outputPathTemplateField = NSTextField()
        outputPathTemplateField.placeholderString = "{output_dir}/{media_type}/{title}"
        outputPathTemplateField.stringValue = "{output_dir}/{media_type}/{title}"

        let templateRow = createLabelControlRow(label: templateLabel, control: outputPathTemplateField)
        sectionStackView.addArrangedSubview(templateRow)

        NSLayoutConstraint.activate([
            sectionStackView.topAnchor.constraint(equalTo: outputDirectoryBox.topAnchor, constant: 25),
            sectionStackView.leadingAnchor.constraint(equalTo: outputDirectoryBox.leadingAnchor, constant: 10),
            sectionStackView.trailingAnchor.constraint(equalTo: outputDirectoryBox.trailingAnchor, constant: -10),
            sectionStackView.bottomAnchor.constraint(equalTo: outputDirectoryBox.bottomAnchor, constant: -10)
        ])
    }

    private func setupQualityPresetsSection(in stackView: NSStackView) {
        qualityPresetsBox = NSBox()
        qualityPresetsBox.title = "Additional Quality Presets"
        qualityPresetsBox.titlePosition = .atTop
        qualityPresetsBox.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(qualityPresetsBox)

        let sectionStackView = NSStackView()
        sectionStackView.orientation = .vertical
        sectionStackView.spacing = 8
        sectionStackView.translatesAutoresizingMaskIntoConstraints = false
        qualityPresetsBox.addSubview(sectionStackView)

        // Preset selection
        let presetLabel = NSTextField(labelWithString: "Quality Preset:")
        presetPopup = NSPopUpButton()
        presetPopup.addItems(withTitles: [
            "Default (High Quality)",
            "Archive (Lossless)",
            "Mobile (Small Size)",
            "Streaming (Balanced)",
            "4K/UHD Optimized",
            "Custom"
        ])
        presetPopup.selectItem(at: 0) // Default preset

        let presetRow = createLabelControlRow(label: presetLabel, control: presetPopup)
        sectionStackView.addArrangedSubview(presetRow)

        // Custom preset management
        let customPresetLabel = NSTextField(labelWithString: "Custom Preset Name:")
        customPresetNameField = NSTextField()
        customPresetNameField.placeholderString = "Enter custom preset name..."

        let customPresetRow = createLabelControlRow(label: customPresetLabel, control: customPresetNameField)
        sectionStackView.addArrangedSubview(customPresetRow)

        // Preset management buttons
        let buttonContainer = NSView()
        buttonContainer.translatesAutoresizingMaskIntoConstraints = false

        savePresetButton = NSButton(title: "Save Current as Preset", target: self, action: #selector(saveCustomPreset))
        deletePresetButton = NSButton(title: "Delete Selected Preset", target: self, action: #selector(deleteCustomPreset))

        savePresetButton.translatesAutoresizingMaskIntoConstraints = false
        deletePresetButton.translatesAutoresizingMaskIntoConstraints = false

        buttonContainer.addSubview(savePresetButton)
        buttonContainer.addSubview(deletePresetButton)

        NSLayoutConstraint.activate([
            savePresetButton.leadingAnchor.constraint(equalTo: buttonContainer.leadingAnchor),
            savePresetButton.topAnchor.constraint(equalTo: buttonContainer.topAnchor),

            deletePresetButton.leadingAnchor.constraint(equalTo: savePresetButton.trailingAnchor, constant: 10),
            deletePresetButton.topAnchor.constraint(equalTo: buttonContainer.topAnchor),

            buttonContainer.heightAnchor.constraint(equalToConstant: 32),
            buttonContainer.trailingAnchor.constraint(greaterThanOrEqualTo: deletePresetButton.trailingAnchor)
        ])

        sectionStackView.addArrangedSubview(buttonContainer)

        NSLayoutConstraint.activate([
            sectionStackView.topAnchor.constraint(equalTo: qualityPresetsBox.topAnchor, constant: 25),
            sectionStackView.leadingAnchor.constraint(equalTo: qualityPresetsBox.leadingAnchor, constant: 10),
            sectionStackView.trailingAnchor.constraint(equalTo: qualityPresetsBox.trailingAnchor, constant: -10),
            sectionStackView.bottomAnchor.constraint(equalTo: qualityPresetsBox.bottomAnchor, constant: -10)
        ])
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

        // Directory creation options
        createSeriesDirectoryCheckbox = NSButton(checkboxWithTitle: "Create separate directories for TV series", target: self, action: nil)
        createSeasonDirectoryCheckbox = NSButton(checkboxWithTitle: "Create season subdirectories for TV shows", target: self, action: nil)

        sectionStackView.addArrangedSubview(createSeriesDirectoryCheckbox)
        sectionStackView.addArrangedSubview(createSeasonDirectoryCheckbox)

        // Custom format fields
        let movieFormatLabel = NSTextField(labelWithString: "Movie Directory Format:")
        movieDirectoryFormatField = NSTextField()
        movieDirectoryFormatField.placeholderString = "Movies/{title} ({year})"
        movieDirectoryFormatField.stringValue = "Movies/{title} ({year})"

        let movieFormatRow = createLabelControlRow(label: movieFormatLabel, control: movieDirectoryFormatField)
        sectionStackView.addArrangedSubview(movieFormatRow)

        let tvFormatLabel = NSTextField(labelWithString: "TV Show Directory Format:")
        tvShowDirectoryFormatField = NSTextField()
        tvShowDirectoryFormatField.placeholderString = "TV Shows/{series}/Season {season}"
        tvShowDirectoryFormatField.stringValue = "TV Shows/{series}/Season {season}"

        let tvFormatRow = createLabelControlRow(label: tvFormatLabel, control: tvShowDirectoryFormatField)
        sectionStackView.addArrangedSubview(tvFormatRow)

        NSLayoutConstraint.activate([
            sectionStackView.topAnchor.constraint(equalTo: fileStorageBox.topAnchor, constant: 25),
            sectionStackView.leadingAnchor.constraint(equalTo: fileStorageBox.leadingAnchor, constant: 10),
            sectionStackView.trailingAnchor.constraint(equalTo: fileStorageBox.trailingAnchor, constant: -10),
            sectionStackView.bottomAnchor.constraint(equalTo: fileStorageBox.bottomAnchor, constant: -10)
        ])
    }

    private func setupBonusContentSection(in stackView: NSStackView) {
        bonusContentBox = NSBox()
        bonusContentBox.title = "Bonus Content"
        bonusContentBox.titlePosition = .atTop
        bonusContentBox.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(bonusContentBox)

        let sectionStackView = NSStackView()
        sectionStackView.orientation = .vertical
        sectionStackView.spacing = 8
        sectionStackView.translatesAutoresizingMaskIntoConstraints = false
        bonusContentBox.addSubview(sectionStackView)

        // Bonus content inclusion options
        includeBonusFeaturesCheckbox = NSButton(checkboxWithTitle: "Include bonus features/special features", target: self, action: nil)
        includeCommentariesCheckbox = NSButton(checkboxWithTitle: "Include audio commentaries", target: self, action: nil)
        includeDeletedScenesCheckbox = NSButton(checkboxWithTitle: "Include deleted scenes", target: self, action: nil)
        includeMakingOfCheckbox = NSButton(checkboxWithTitle: "Include making-of documentaries", target: self, action: nil)
        includeTrailersCheckbox = NSButton(checkboxWithTitle: "Include trailers and previews", target: self, action: nil)

        sectionStackView.addArrangedSubview(includeBonusFeaturesCheckbox)
        sectionStackView.addArrangedSubview(includeCommentariesCheckbox)
        sectionStackView.addArrangedSubview(includeDeletedScenesCheckbox)
        sectionStackView.addArrangedSubview(includeMakingOfCheckbox)
        sectionStackView.addArrangedSubview(includeTrailersCheckbox)

        // Bonus content organization
        let bonusStructureLabel = NSTextField(labelWithString: "Bonus Content Organization:")
        bonusContentStructurePopup = NSPopUpButton()
        bonusContentStructurePopup.addItems(withTitles: [
            "Same directory as main content",
            "Separate 'Bonus' subdirectory",
            "Separate 'Extras' subdirectory",
            "Custom subdirectory name"
        ])
        bonusContentStructurePopup.selectItem(at: 1) // Default to "Separate 'Bonus' subdirectory"

        let bonusStructureRow = createLabelControlRow(label: bonusStructureLabel, control: bonusContentStructurePopup)
        sectionStackView.addArrangedSubview(bonusStructureRow)

        let bonusDirLabel = NSTextField(labelWithString: "Custom Bonus Directory Name:")
        bonusContentDirectoryField = NSTextField()
        bonusContentDirectoryField.placeholderString = "Bonus"
        bonusContentDirectoryField.stringValue = "Bonus"

        let bonusDirRow = createLabelControlRow(label: bonusDirLabel, control: bonusContentDirectoryField)
        sectionStackView.addArrangedSubview(bonusDirRow)

        NSLayoutConstraint.activate([
            sectionStackView.topAnchor.constraint(equalTo: bonusContentBox.topAnchor, constant: 25),
            sectionStackView.leadingAnchor.constraint(equalTo: bonusContentBox.leadingAnchor, constant: 10),
            sectionStackView.trailingAnchor.constraint(equalTo: bonusContentBox.trailingAnchor, constant: -10),
            sectionStackView.bottomAnchor.constraint(equalTo: bonusContentBox.bottomAnchor, constant: -10)
        ])
    }

    private func setupFileNamingSection(in stackView: NSStackView) {
        fileNamingBox = NSBox()
        fileNamingBox.title = "File Naming"
        fileNamingBox.titlePosition = .atTop
        fileNamingBox.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(fileNamingBox)

        let sectionStackView = NSStackView()
        sectionStackView.orientation = .vertical
        sectionStackView.spacing = 8
        sectionStackView.translatesAutoresizingMaskIntoConstraints = false
        fileNamingBox.addSubview(sectionStackView)

        // File naming formats
        let movieFileLabel = NSTextField(labelWithString: "Movie File Format:")
        movieFileFormatField = NSTextField()
        movieFileFormatField.placeholderString = "{title} ({year}).mkv"
        movieFileFormatField.stringValue = "{title} ({year}).mkv"

        let movieFileRow = createLabelControlRow(label: movieFileLabel, control: movieFileFormatField)
        sectionStackView.addArrangedSubview(movieFileRow)

        let tvFileLabel = NSTextField(labelWithString: "TV Episode File Format:")
        tvShowFileFormatField = NSTextField()
        tvShowFileFormatField.placeholderString = "{series} - S{season:02d}E{episode:02d} - {title}.mkv"
        tvShowFileFormatField.stringValue = "{series} - S{season:02d}E{episode:02d} - {title}.mkv"

        let tvFileRow = createLabelControlRow(label: tvFileLabel, control: tvShowFileFormatField)
        sectionStackView.addArrangedSubview(tvFileRow)

        let seasonEpisodeLabel = NSTextField(labelWithString: "Season/Episode Format:")
        seasonEpisodeFormatField = NSTextField()
        seasonEpisodeFormatField.placeholderString = "S{season:02d}E{episode:02d}"
        seasonEpisodeFormatField.stringValue = "S{season:02d}E{episode:02d}"

        let seasonEpisodeRow = createLabelControlRow(label: seasonEpisodeLabel, control: seasonEpisodeFormatField)
        sectionStackView.addArrangedSubview(seasonEpisodeRow)

        // Filename options
        includeYearInFilenameCheckbox = NSButton(checkboxWithTitle: "Include year in filename", target: self, action: nil)
        includeResolutionInFilenameCheckbox = NSButton(checkboxWithTitle: "Include resolution in filename", target: self, action: nil)
        includeCodecInFilenameCheckbox = NSButton(checkboxWithTitle: "Include codec info in filename", target: self, action: nil)

        sectionStackView.addArrangedSubview(includeYearInFilenameCheckbox)
        sectionStackView.addArrangedSubview(includeResolutionInFilenameCheckbox)
        sectionStackView.addArrangedSubview(includeCodecInFilenameCheckbox)

        NSLayoutConstraint.activate([
            sectionStackView.topAnchor.constraint(equalTo: fileNamingBox.topAnchor, constant: 25),
            sectionStackView.leadingAnchor.constraint(equalTo: fileNamingBox.leadingAnchor, constant: 10),
            sectionStackView.trailingAnchor.constraint(equalTo: fileNamingBox.trailingAnchor, constant: -10),
            sectionStackView.bottomAnchor.constraint(equalTo: fileNamingBox.bottomAnchor, constant: -10)
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

        let languageLabel = NSTextField(labelWithString: "Preferred Language:")
        preferredLanguagePopup = NSPopUpButton()
        preferredLanguagePopup.addItems(withTitles: ["English", "Spanish", "French", "German", "Japanese", "Auto-detect", "All Languages"])
        preferredLanguagePopup.selectItem(at: 0) // Default to English

        let languageRow = createLabelControlRow(label: languageLabel, control: preferredLanguagePopup)
        sectionStackView.addArrangedSubview(languageRow)

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

        // Advanced options
        preserveOriginalTimestampsCheckbox = NSButton(checkboxWithTitle: "Preserve original file timestamps", target: self, action: nil)
        createBackupsCheckbox = NSButton(checkboxWithTitle: "Create backup of original disc structure", target: self, action: nil)
        autoRetryOnFailureCheckbox = NSButton(checkboxWithTitle: "Auto-retry on failure", target: self, action: nil)

        sectionStackView.addArrangedSubview(preserveOriginalTimestampsCheckbox)
        sectionStackView.addArrangedSubview(createBackupsCheckbox)
        sectionStackView.addArrangedSubview(autoRetryOnFailureCheckbox)

        let maxRetriesLabel = NSTextField(labelWithString: "Max Retry Attempts:")
        maxRetryAttemptsField = NSTextField()
        maxRetryAttemptsField.stringValue = "3"
        maxRetryAttemptsField.placeholderString = "3"

        let maxRetriesRow = createLabelControlRow(label: maxRetriesLabel, control: maxRetryAttemptsField)
        sectionStackView.addArrangedSubview(maxRetriesRow)

        let scriptLabel = NSTextField(labelWithString: "Post-processing Script:")
        postProcessingScriptField = NSTextField()
        postProcessingScriptField.placeholderString = "Path to script to run after ripping..."
        browseScriptButton = NSButton(title: "Browse...", target: self, action: #selector(browseForScript))

        let scriptRow = createLabelControlButtonRow(label: scriptLabel, control: postProcessingScriptField, button: browseScriptButton)
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
        control.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(label)
        container.addSubview(control)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            label.widthAnchor.constraint(equalToConstant: 200),

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

        // File Organization settings (NEW)
        autoRenameFilesCheckbox.state = defaults.bool(forKey: "autoRenameFiles") ? .on : .off
        createYearDirectoriesCheckbox.state = defaults.bool(forKey: "createYearDirectories") ? .on : .off
        createGenreDirectoriesCheckbox.state = defaults.bool(forKey: "createGenreDirectories") ? .on : .off
        duplicateHandlingPopup.selectItem(at: defaults.integer(forKey: "duplicateHandling"))
        minimumFileSizeField.stringValue = String(defaults.integer(forKey: "minimumFileSize"))
        if minimumFileSizeField.stringValue == "0" {
            minimumFileSizeField.stringValue = "100" // Default
        }

        // Advanced Encoding settings (NEW)
        encodingSpeedPopup.selectItem(at: defaults.integer(forKey: "encodingSpeed"))
        bitrateControlPopup.selectItem(at: defaults.integer(forKey: "bitrateControl"))
        if let targetBitrate = defaults.string(forKey: "targetBitrate"), !targetBitrate.isEmpty {
            targetBitrateField.stringValue = targetBitrate
        }
        twoPassEncodingCheckbox.state = defaults.bool(forKey: "twoPassEncoding") ? .on : .off
        hardwareAccelerationCheckbox.state = settingsManager.hardwareAcceleration ? .on : .off
        if let customArgs = defaults.string(forKey: "customFFmpegArgs") {
            customFFmpegArgsField.stringValue = customArgs
        }

        // Output Directory settings (NEW)
        if let defaultPath = defaults.string(forKey: "defaultOutputPath"), !defaultPath.isEmpty {
            defaultOutputPathField.stringValue = defaultPath
        }
        createDateDirectoriesCheckbox.state = defaults.bool(forKey: "createDateDirectories") ? .on : .off
        if let pathTemplate = defaults.string(forKey: "outputPathTemplate"), !pathTemplate.isEmpty {
            outputPathTemplateField.stringValue = pathTemplate
        }

        // Quality Presets settings (NEW)
        presetPopup.selectItem(at: defaults.integer(forKey: "selectedQualityPreset"))
        if let customPresetName = defaults.string(forKey: "customPresetName") {
            customPresetNameField.stringValue = customPresetName
        }

        // File Storage settings
        outputStructurePopup.selectItem(at: defaults.integer(forKey: "outputStructureType"))
        createSeriesDirectoryCheckbox.state = defaults.bool(forKey: "createSeriesDirectory") ? .on : .off
        createSeasonDirectoryCheckbox.state = defaults.bool(forKey: "createSeasonDirectory") ? .on : .off

        if let movieFormat = defaults.string(forKey: "movieDirectoryFormat") {
            movieDirectoryFormatField.stringValue = movieFormat
        }
        if let tvFormat = defaults.string(forKey: "tvShowDirectoryFormat") {
            tvShowDirectoryFormatField.stringValue = tvFormat
        }

        // Bonus Content settings
        includeBonusFeaturesCheckbox.state = defaults.bool(forKey: "includeBonusFeatures") ? .on : .off
        includeCommentariesCheckbox.state = defaults.bool(forKey: "includeCommentaries") ? .on : .off
        includeDeletedScenesCheckbox.state = defaults.bool(forKey: "includeDeletedScenes") ? .on : .off
        includeMakingOfCheckbox.state = defaults.bool(forKey: "includeMakingOf") ? .on : .off
        includeTrailersCheckbox.state = defaults.bool(forKey: "includeTrailers") ? .on : .off

        bonusContentStructurePopup.selectItem(at: defaults.integer(forKey: "bonusContentStructure"))
        if let bonusDir = defaults.string(forKey: "bonusContentDirectory") {
            bonusContentDirectoryField.stringValue = bonusDir
        }

        // File Naming settings
        if let movieFileFormat = defaults.string(forKey: "movieFileFormat") {
            movieFileFormatField.stringValue = movieFileFormat
        }
        if let tvFileFormat = defaults.string(forKey: "tvShowFileFormat") {
            tvShowFileFormatField.stringValue = tvFileFormat
        }
        if let seasonEpisodeFormat = defaults.string(forKey: "seasonEpisodeFormat") {
            seasonEpisodeFormatField.stringValue = seasonEpisodeFormat
        }

        includeYearInFilenameCheckbox.state = defaults.bool(forKey: "includeYearInFilename") ? .on : .off
        includeResolutionInFilenameCheckbox.state = defaults.bool(forKey: "includeResolutionInFilename") ? .on : .off
        includeCodecInFilenameCheckbox.state = defaults.bool(forKey: "includeCodecInFilename") ? .on : .off

        // Advanced settings
        preserveOriginalTimestampsCheckbox.state = defaults.bool(forKey: "preserveOriginalTimestamps") ? .on : .off
        createBackupsCheckbox.state = defaults.bool(forKey: "createBackups") ? .on : .off
        autoRetryOnFailureCheckbox.state = defaults.bool(forKey: "autoRetryOnFailure") ? .on : .off
        maxRetryAttemptsField.stringValue = String(defaults.integer(forKey: "maxRetryAttempts"))
        if maxRetryAttemptsField.stringValue == "0" {
            maxRetryAttemptsField.stringValue = "3" // Default
        }

        if let scriptPath = defaults.string(forKey: "postProcessingScript") {
            postProcessingScriptField.stringValue = scriptPath
        }
    }

    // MARK: - Actions

    @objc private func browseForScript() {
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        if #available(macOS 12.0, *) {
            openPanel.allowedContentTypes = [.shellScript, .pythonScript, .rubyScript, .perlScript, .javaScript]
        } else {
            openPanel.allowedFileTypes = ["sh", "py", "rb", "pl", "js"]
        }
        openPanel.title = "Select Post-processing Script"

        if openPanel.runModal() == .OK {
            if let url = openPanel.url {
                postProcessingScriptField.stringValue = url.path
            }
        }
    }

    @objc private func browseForOutputDirectory() {
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        openPanel.title = "Select Default Output Directory"

        if openPanel.runModal() == .OK {
            if let url = openPanel.url {
                defaultOutputPathField.stringValue = url.path
            }
        }
    }

    @objc private func saveCustomPreset() {
        guard !customPresetNameField.stringValue.isEmpty else {
            let alert = NSAlert()
            alert.messageText = "Invalid Preset Name"
            alert.informativeText = "Please enter a name for the custom preset."
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }

        let presetName = customPresetNameField.stringValue

        // Save current settings as a preset (implementation would save to UserDefaults or a plist)
        let defaults = UserDefaults.standard
        let presetKey = "custom_preset_\(presetName)"

        let presetData: [String: Any] = [
            "videoCodec": videoCodecPopup.titleOfSelectedItem ?? "H.264 (x264)",
            "audioCodec": audioCodecPopup.titleOfSelectedItem ?? "AAC",
            "quality": qualityPopup.indexOfSelectedItem,
            "encodingSpeed": encodingSpeedPopup.indexOfSelectedItem,
            "bitrateControl": bitrateControlPopup.indexOfSelectedItem,
            "targetBitrate": targetBitrateField.stringValue,
            "twoPassEncoding": twoPassEncodingCheckbox.state == .on,
            "hardwareAcceleration": hardwareAccelerationCheckbox.state == .on
        ]

        defaults.set(presetData, forKey: presetKey)

        // Add to preset popup
        let existingTitles = presetPopup.itemTitles
        if !existingTitles.contains(presetName) {
            presetPopup.addItem(withTitle: presetName)
        }

        presetPopup.selectItem(withTitle: presetName)

        let alert = NSAlert()
        alert.messageText = "Preset Saved"
        alert.informativeText = "Custom preset '\(presetName)' has been saved."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc private func deleteCustomPreset() {
        let selectedPreset = presetPopup.titleOfSelectedItem
        guard let presetName = selectedPreset,
              !presetName.hasPrefix("Default") &&
              !presetName.hasPrefix("Archive") &&
              !presetName.hasPrefix("Mobile") &&
              !presetName.hasPrefix("Streaming") &&
              !presetName.hasPrefix("4K") else {
            let alert = NSAlert()
            alert.messageText = "Cannot Delete Preset"
            alert.informativeText = "Built-in presets cannot be deleted. Only custom presets can be removed."
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }

        let alert = NSAlert()
        alert.messageText = "Delete Preset"
        alert.informativeText = "Are you sure you want to delete the preset '\(presetName)'?"
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            // Remove from UserDefaults
            let defaults = UserDefaults.standard
            let presetKey = "custom_preset_\(presetName)"
            defaults.removeObject(forKey: presetKey)

            // Remove from popup
            presetPopup.removeItem(withTitle: presetName)
            presetPopup.selectItem(at: 0) // Select default
        }
    }

    @objc private func restoreDefaults() {
        // Reset File Organization settings (NEW)
        autoRenameFilesCheckbox.state = .on
        createYearDirectoriesCheckbox.state = .off
        createGenreDirectoriesCheckbox.state = .off
        duplicateHandlingPopup.selectItem(at: 2) // Rename with suffix
        minimumFileSizeField.stringValue = "100"

        // Reset Advanced Encoding settings (NEW)
        encodingSpeedPopup.selectItem(at: 3) // Medium
        bitrateControlPopup.selectItem(at: 0) // CRF
        targetBitrateField.stringValue = "5.0"
        twoPassEncodingCheckbox.state = .off
        hardwareAccelerationCheckbox.state = .off
        customFFmpegArgsField.stringValue = ""

        // Reset Output Directory settings (NEW)
        defaultOutputPathField.stringValue = "~/Movies/Ripped"
        createDateDirectoriesCheckbox.state = .off
        outputPathTemplateField.stringValue = "{output_dir}/{media_type}/{title}"

        // Reset Quality Presets settings (NEW)
        presetPopup.selectItem(at: 0) // Default
        customPresetNameField.stringValue = ""

        // Reset existing settings to default values
        outputStructurePopup.selectItem(at: 1) // By Media Type
        createSeriesDirectoryCheckbox.state = .on
        createSeasonDirectoryCheckbox.state = .on
        movieDirectoryFormatField.stringValue = "Movies/{title} ({year})"
        tvShowDirectoryFormatField.stringValue = "TV Shows/{series}/Season {season}"

        includeBonusFeaturesCheckbox.state = .off
        includeCommentariesCheckbox.state = .off
        includeDeletedScenesCheckbox.state = .off
        includeMakingOfCheckbox.state = .off
        includeTrailersCheckbox.state = .off
        bonusContentStructurePopup.selectItem(at: 1) // Separate 'Bonus' subdirectory
        bonusContentDirectoryField.stringValue = "Bonus"

        movieFileFormatField.stringValue = "{title} ({year}).mkv"
        tvShowFileFormatField.stringValue = "{series} - S{season:02d}E{episode:02d} - {title}.mkv"
        seasonEpisodeFormatField.stringValue = "S{season:02d}E{episode:02d}"
        includeYearInFilenameCheckbox.state = .on
        includeResolutionInFilenameCheckbox.state = .off
        includeCodecInFilenameCheckbox.state = .off

        videoCodecPopup.selectItem(at: 0) // H.264
        audioCodecPopup.selectItem(at: 0) // AAC
        qualityPopup.selectItem(at: 2) // High
        includeSubtitlesCheckbox.state = .on
        includeChaptersCheckbox.state = .on
        preferredLanguagePopup.selectItem(at: 0) // English

        preserveOriginalTimestampsCheckbox.state = .off
        createBackupsCheckbox.state = .off
        autoRetryOnFailureCheckbox.state = .on
        maxRetryAttemptsField.stringValue = "3"
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

        // File Organization settings (NEW)
        defaults.set(autoRenameFilesCheckbox.state == .on, forKey: "autoRenameFiles")
        defaults.set(createYearDirectoriesCheckbox.state == .on, forKey: "createYearDirectories")
        defaults.set(createGenreDirectoriesCheckbox.state == .on, forKey: "createGenreDirectories")
        defaults.set(duplicateHandlingPopup.indexOfSelectedItem, forKey: "duplicateHandling")
        defaults.set(Int(minimumFileSizeField.stringValue) ?? 100, forKey: "minimumFileSize")

        // Advanced Encoding settings (NEW)
        defaults.set(encodingSpeedPopup.indexOfSelectedItem, forKey: "encodingSpeed")
        defaults.set(bitrateControlPopup.indexOfSelectedItem, forKey: "bitrateControl")
        defaults.set(targetBitrateField.stringValue, forKey: "targetBitrate")
        defaults.set(twoPassEncodingCheckbox.state == .on, forKey: "twoPassEncoding")
        settingsManager.hardwareAcceleration = hardwareAccelerationCheckbox.state == .on
        defaults.set(customFFmpegArgsField.stringValue, forKey: "customFFmpegArgs")

        // Output Directory settings (NEW)
        defaults.set(defaultOutputPathField.stringValue, forKey: "defaultOutputPath")
        defaults.set(createDateDirectoriesCheckbox.state == .on, forKey: "createDateDirectories")
        defaults.set(outputPathTemplateField.stringValue, forKey: "outputPathTemplate")

        // Quality Presets settings (NEW)
        defaults.set(presetPopup.indexOfSelectedItem, forKey: "selectedQualityPreset")
        defaults.set(customPresetNameField.stringValue, forKey: "customPresetName")

        // File Storage settings
        defaults.set(outputStructurePopup.indexOfSelectedItem, forKey: "outputStructureType")
        defaults.set(createSeriesDirectoryCheckbox.state == .on, forKey: "createSeriesDirectory")
        defaults.set(createSeasonDirectoryCheckbox.state == .on, forKey: "createSeasonDirectory")
        defaults.set(movieDirectoryFormatField.stringValue, forKey: "movieDirectoryFormat")
        defaults.set(tvShowDirectoryFormatField.stringValue, forKey: "tvShowDirectoryFormat")

        // Bonus Content settings
        defaults.set(includeBonusFeaturesCheckbox.state == .on, forKey: "includeBonusFeatures")
        defaults.set(includeCommentariesCheckbox.state == .on, forKey: "includeCommentaries")
        defaults.set(includeDeletedScenesCheckbox.state == .on, forKey: "includeDeletedScenes")
        defaults.set(includeMakingOfCheckbox.state == .on, forKey: "includeMakingOf")
        defaults.set(includeTrailersCheckbox.state == .on, forKey: "includeTrailers")
        defaults.set(bonusContentStructurePopup.indexOfSelectedItem, forKey: "bonusContentStructure")
        defaults.set(bonusContentDirectoryField.stringValue, forKey: "bonusContentDirectory")

        // File Naming settings
        defaults.set(movieFileFormatField.stringValue, forKey: "movieFileFormat")
        defaults.set(tvShowFileFormatField.stringValue, forKey: "tvShowFileFormat")
        defaults.set(seasonEpisodeFormatField.stringValue, forKey: "seasonEpisodeFormat")
        defaults.set(includeYearInFilenameCheckbox.state == .on, forKey: "includeYearInFilename")
        defaults.set(includeResolutionInFilenameCheckbox.state == .on, forKey: "includeResolutionInFilename")
        defaults.set(includeCodecInFilenameCheckbox.state == .on, forKey: "includeCodecInFilename")

        // Advanced settings
        defaults.set(preserveOriginalTimestampsCheckbox.state == .on, forKey: "preserveOriginalTimestamps")
        defaults.set(createBackupsCheckbox.state == .on, forKey: "createBackups")
        defaults.set(autoRetryOnFailureCheckbox.state == .on, forKey: "autoRetryOnFailure")
        defaults.set(Int(maxRetryAttemptsField.stringValue) ?? 3, forKey: "maxRetryAttempts")
        defaults.set(postProcessingScriptField.stringValue, forKey: "postProcessingScript")

        defaults.synchronize()
    }
}
