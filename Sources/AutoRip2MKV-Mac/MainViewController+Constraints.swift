import Cocoa

// MARK: - Constraints Setup

extension MainViewController {

    func setupConstraints() {
        logHeightConstraint = scrollView.heightAnchor.constraint(equalToConstant: 180)

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
            sourceDropDown.trailingAnchor.constraint(
                equalTo: refreshDrivesButton.leadingAnchor, constant: -10
            ),

            refreshDrivesButton.topAnchor.constraint(equalTo: sourceDropDown.topAnchor),
            refreshDrivesButton.trailingAnchor.constraint(
                equalTo: browseSourceButton.leadingAnchor, constant: -10
            ),
            refreshDrivesButton.widthAnchor.constraint(equalToConstant: 80),

            browseSourceButton.topAnchor.constraint(equalTo: sourceDropDown.topAnchor),
            browseSourceButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            browseSourceButton.widthAnchor.constraint(equalToConstant: 80),

            // Output Path
            outputPathField.topAnchor.constraint(equalTo: sourceDropDown.bottomAnchor, constant: 20),
            outputPathField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            outputPathField.trailingAnchor.constraint(
                equalTo: browseOutputButton.leadingAnchor, constant: -10
            ),

            browseOutputButton.topAnchor.constraint(equalTo: outputPathField.topAnchor),
            browseOutputButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            browseOutputButton.widthAnchor.constraint(equalToConstant: 80),

            // Automation Settings — three checkboxes stacked, settings button at right
            autoRipCheckbox.topAnchor.constraint(equalTo: outputPathField.bottomAnchor, constant: 20),
            autoRipCheckbox.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            autoEjectCheckbox.topAnchor.constraint(equalTo: autoRipCheckbox.bottomAnchor, constant: 5),
            autoEjectCheckbox.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            skipRippedCheckbox.topAnchor.constraint(equalTo: autoEjectCheckbox.bottomAnchor, constant: 5),
            skipRippedCheckbox.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            settingsButton.topAnchor.constraint(equalTo: autoRipCheckbox.topAnchor),
            settingsButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            settingsButton.widthAnchor.constraint(equalToConstant: 80),

            reviewRipsButton.centerYAnchor.constraint(equalTo: settingsButton.centerYAnchor),
            reviewRipsButton.trailingAnchor.constraint(equalTo: settingsButton.leadingAnchor, constant: -8),

            // Rip Button
            ripButton.topAnchor.constraint(equalTo: skipRippedCheckbox.bottomAnchor, constant: 20),
            ripButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            ripButton.widthAnchor.constraint(equalToConstant: 120),

            // Progress Indicator
            progressIndicator.topAnchor.constraint(equalTo: ripButton.bottomAnchor, constant: 20),
            progressIndicator.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            progressIndicator.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            // Progress Status Label
            progressStatusLabel.topAnchor.constraint(equalTo: progressIndicator.bottomAnchor, constant: 4),
            progressStatusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            progressStatusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            // Queue table fills the space between progress and the log disclosure
            queueScrollView.topAnchor.constraint(equalTo: progressStatusLabel.bottomAnchor, constant: 8),
            queueScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            queueScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            queueScrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 120),

            // Log disclosure row
            logDisclosureButton.topAnchor.constraint(equalTo: queueScrollView.bottomAnchor, constant: 8),
            logDisclosureButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            logDisclosureLabel.centerYAnchor.constraint(equalTo: logDisclosureButton.centerYAnchor),
            logDisclosureLabel.leadingAnchor.constraint(
                equalTo: logDisclosureButton.trailingAnchor, constant: 4
            ),

            // Log Text View (collapsed by default via logHeightConstraint)
            scrollView.topAnchor.constraint(equalTo: logDisclosureButton.bottomAnchor, constant: 6),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),
            logHeightConstraint
        ])
    }
}
