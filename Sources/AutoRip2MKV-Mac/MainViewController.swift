import Cocoa

class MainViewController: NSViewController {
    
    // UI Elements
    private var titleLabel: NSTextField!
    private var sourcePathField: NSTextField!
    private var browseSourceButton: NSButton!
    private var outputPathField: NSTextField!
    private var browseOutputButton: NSButton!
    private var ripButton: NSButton!
    private var progressIndicator: NSProgressIndicator!
    private var logTextView: NSTextView!
    private var scrollView: NSScrollView!
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        setupUI()
    }
    
    private func setupUI() {
        // Title Label
        titleLabel = NSTextField(labelWithString: "AutoRip2MKV for Mac")
        titleLabel.font = NSFont.systemFont(ofSize: 24, weight: .bold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)
        
        // Source Path Section
        let sourceLabel = NSTextField(labelWithString: "Source DVD/Blu-ray Path:")
        sourceLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(sourceLabel)
        
        sourcePathField = NSTextField()
        sourcePathField.placeholderString = "Select source directory..."
        sourcePathField.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(sourcePathField)
        
        browseSourceButton = NSButton(title: "Browse", target: self, action: #selector(browseSourcePath))
        browseSourceButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(browseSourceButton)
        
        // Output Path Section
        let outputLabel = NSTextField(labelWithString: "Output Directory:")
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
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Title
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            // Source Path
            sourcePathField.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 40),
            sourcePathField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            sourcePathField.trailingAnchor.constraint(equalTo: browseSourceButton.leadingAnchor, constant: -10),
            
            browseSourceButton.topAnchor.constraint(equalTo: sourcePathField.topAnchor),
            browseSourceButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            browseSourceButton.widthAnchor.constraint(equalToConstant: 80),
            
            // Output Path
            outputPathField.topAnchor.constraint(equalTo: sourcePathField.bottomAnchor, constant: 20),
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
        
        if openPanel.runModal() == .OK {
            if let url = openPanel.url {
                sourcePathField.stringValue = url.path
            }
        }
    }
    
    @objc private func browseOutputPath() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.title = "Select Output Directory"
        
        if openPanel.runModal() == .OK {
            if let url = openPanel.url {
                outputPathField.stringValue = url.path
            }
        }
    }
    
    @objc private func startRipping() {
        guard !sourcePathField.stringValue.isEmpty && !outputPathField.stringValue.isEmpty else {
            showAlert(title: "Error", message: "Please select both source and output directories.")
            return
        }
        
        // Start the ripping process
        ripButton.isEnabled = false
        progressIndicator.isHidden = false
        progressIndicator.startAnimation(nil)
        
        appendToLog("Starting ripping process...")
        appendToLog("Source: \(sourcePathField.stringValue)")
        appendToLog("Output: \(outputPathField.stringValue)")
        
        // TODO: Implement the actual ripping logic
        // For now, we'll just simulate the process
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.appendToLog("Ripping process completed!")
            self.progressIndicator.stopAnimation(nil)
            self.progressIndicator.isHidden = true
            self.ripButton.isEnabled = true
        }
    }
    
    private func appendToLog(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let logMessage = "[\(timestamp)] \(message)\n"
        
        logTextView.textStorage?.append(NSAttributedString(string: logMessage))
        logTextView.scrollToEndOfDocument(nil)
    }
    
    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }
}
