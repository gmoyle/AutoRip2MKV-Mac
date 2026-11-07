import Cocoa

class DetailedSettingsWindowControllerNew: NSWindowController {

    // MARK: - Properties
    private var settingsManager = SettingsManager.shared

    // MARK: - UI Elements (simplified for testing)
    private var testLabel: NSTextField!
    private var okButton: NSButton!
    private var cancelButton: NSButton!

    override func windowDidLoad() {
        super.windowDidLoad()
        print("[DEBUG] windowDidLoad called")
        setupWindow()
        setupUI()
        print("[DEBUG] windowDidLoad completed")
    }

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Detailed Settings (Test)"
        window.center()

        self.init(window: window)
    }

    private func setupWindow() {
        print("[DEBUG] setupWindow called")
        print("[DEBUG] window: \(String(describing: window))")
        window?.isReleasedWhenClosed = false
        window?.level = NSWindow.Level.modalPanel
        print("[DEBUG] setupWindow completed")
    }

    private func setupUI() {
        print("[DEBUG] setupUI called")
        guard let contentView = window?.contentView else {
            print("[DEBUG] ERROR: contentView is nil!")
            return
        }
        print("[DEBUG] contentView: \(contentView)")

        // Create a simple test label
        testLabel = NSTextField(labelWithString: "Settings window is working! This is a test.")
        testLabel.font = NSFont.systemFont(ofSize: 16)
        testLabel.alignment = .center
        testLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(testLabel)

        // Create buttons
        let buttonStackView = NSStackView()
        buttonStackView.orientation = .horizontal
        buttonStackView.spacing = 12
        buttonStackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(buttonStackView)

        cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancelSettings))
        okButton = NSButton(title: "OK", target: self, action: #selector(applySettings))

        okButton.keyEquivalent = "\r"
        cancelButton.keyEquivalent = "\u{1b}"

        buttonStackView.addArrangedSubview(NSView()) // Spacer
        buttonStackView.addArrangedSubview(cancelButton)
        buttonStackView.addArrangedSubview(okButton)

        // Simple constraints
        print("[DEBUG] Setting up constraints")
        NSLayoutConstraint.activate([
            testLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            testLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            buttonStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            buttonStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            buttonStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            buttonStackView.heightAnchor.constraint(equalToConstant: 32)
        ])
        print("[DEBUG] setupUI completed")
    }

    @objc private func cancelSettings() {
        window?.close()
    }

    @objc private func applySettings() {
        window?.close()
    }
}
