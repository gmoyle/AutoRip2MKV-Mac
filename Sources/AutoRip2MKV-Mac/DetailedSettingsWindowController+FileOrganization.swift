import Cocoa

// MARK: - File Organization Section

extension DetailedSettingsWindowController {

    func setupFileOrganizationSection(in parentStackView: NSStackView) {
        fileOrganizationBox = NSBox()
        fileOrganizationBox.title = "File Organization"
        fileOrganizationBox.titlePosition = .atTop
        fileOrganizationBox.boxType = .primary
        fileOrganizationBox.translatesAutoresizingMaskIntoConstraints = false

        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.spacing = 10
        stackView.alignment = .leading
        stackView.translatesAutoresizingMaskIntoConstraints = false
        fileOrganizationBox.contentView = stackView

        // Auto-rename files
        autoRenameFilesCheckbox = NSButton(checkboxWithTitle: "Automatically rename files", target: nil, action: nil)
        autoRenameFilesCheckbox.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(autoRenameFilesCheckbox)

        // Create year directories
        createYearDirectoriesCheckbox = NSButton(
            checkboxWithTitle: "Create year subdirectories",
            target: nil,
            action: nil
        )
        createYearDirectoriesCheckbox.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(createYearDirectoriesCheckbox)

        // Create genre directories
        createGenreDirectoriesCheckbox = NSButton(
            checkboxWithTitle: "Create genre subdirectories",
            target: nil,
            action: nil
        )
        createGenreDirectoriesCheckbox.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(createGenreDirectoriesCheckbox)

        // Duplicate handling
        let duplicateLabel = NSTextField(labelWithString: "Duplicate file handling:")
        duplicateLabel.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(duplicateLabel)

        duplicateHandlingPopup = NSPopUpButton()
        duplicateHandlingPopup.addItems(withTitles: ["Skip", "Overwrite", "Rename", "Ask"])
        duplicateHandlingPopup.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(duplicateHandlingPopup)

        // Minimum file size
        let sizeLabel = NSTextField(labelWithString: "Minimum file size (MB):")
        sizeLabel.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(sizeLabel)

        minimumFileSizeField = NSTextField()
        minimumFileSizeField.placeholderString = "100"
        minimumFileSizeField.translatesAutoresizingMaskIntoConstraints = false
        minimumFileSizeField.widthAnchor.constraint(equalToConstant: 100).isActive = true
        stackView.addArrangedSubview(minimumFileSizeField)

        parentStackView.addArrangedSubview(fileOrganizationBox)
    }

    func loadFileOrganizationSettings() {
        let defaults = UserDefaults.standard

        autoRenameFilesCheckbox.state = defaults.bool(forKey: "autoRenameFiles") ? .on : .off
        createYearDirectoriesCheckbox.state = defaults.bool(forKey: "createYearDirectories") ? .on : .off
        createGenreDirectoriesCheckbox.state = defaults.bool(forKey: "createGenreDirectories") ? .on : .off

        let duplicateHandling = defaults.integer(forKey: "duplicateHandling")
        duplicateHandlingPopup.selectItem(at: duplicateHandling)

        let minSize = defaults.integer(forKey: "minimumFileSize")
        minimumFileSizeField.stringValue = minSize > 0 ? String(minSize) : "100"
    }

    func saveFileOrganizationSettings() {
        let defaults = UserDefaults.standard

        defaults.set(autoRenameFilesCheckbox.state == .on, forKey: "autoRenameFiles")
        defaults.set(createYearDirectoriesCheckbox.state == .on, forKey: "createYearDirectories")
        defaults.set(createGenreDirectoriesCheckbox.state == .on, forKey: "createGenreDirectories")
        defaults.set(duplicateHandlingPopup.indexOfSelectedItem, forKey: "duplicateHandling")

        if let minSize = Int(minimumFileSizeField.stringValue), minSize > 0 {
            defaults.set(minSize, forKey: "minimumFileSize")
        } else {
            defaults.set(100, forKey: "minimumFileSize")
        }
    }
}
