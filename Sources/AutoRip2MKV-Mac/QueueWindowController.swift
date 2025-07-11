import Cocoa
import UserNotifications

/// Window controller for displaying and managing the conversion queue
class QueueWindowController: NSWindowController {

    // MARK: - Outlets

    @IBOutlet var queueTableView: NSTableView?
    @IBOutlet var statusLabel: NSTextField?
    @IBOutlet var clearCompletedButton: NSButton?
    @IBOutlet var cancelAllButton: NSButton?
    @IBOutlet var refreshButton: NSButton?

    // MARK: - Properties

    private var conversionQueue: ConversionQueue!
    private var jobs: [ConversionQueue.ConversionJob] = []
    private var refreshTimer: Timer?

    // MARK: - Initialization

    convenience init(conversionQueue: ConversionQueue) {
        // Always try XIB first, fallback to programmatic creation
        self.init(windowNibName: "QueueWindow")
        self.conversionQueue = conversionQueue
        // Delay delegate assignment until after window is loaded
    }

    override func loadWindow() {
        // Try to load XIB first, but handle failure gracefully
        if Bundle.main.path(forResource: "QueueWindow", ofType: "nib") != nil {
            super.loadWindow()
            if window != nil {
                return
            }
        }

        // Fallback to programmatic creation (for tests or when XIB is missing)
        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 500),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        newWindow.title = "Conversion Queue"
        newWindow.center()
        self.window = newWindow
    }

    override func windowDidLoad() {
        super.windowDidLoad()

        // Set up delegate after window is loaded
        if conversionQueue != nil {
            conversionQueue.delegate = self
        }

        setupWindow()
        setupTableView()
        setupUI()
        refreshQueueData()
        startRefreshTimer()
    }

    func windowWillClose(_ notification: Notification) {
        stopRefreshTimer()
    }

    // MARK: - Setup

    private func setupWindow() {
        window?.title = "Conversion Queue"
        window?.setContentSize(NSSize(width: 800, height: 500))
        window?.center()
    }

    private func setupTableView() {
        // Create columns programmatically since we don't have a XIB
        createTableColumns()

        queueTableView?.delegate = self
        queueTableView?.dataSource = self
        queueTableView?.allowsMultipleSelection = true
        queueTableView?.usesAlternatingRowBackgroundColors = true
    }

    private func createTableColumns() {
        guard let tableView = queueTableView else { return }

        // Title column
        let titleColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("title"))
        titleColumn.title = "Disc Title"
        titleColumn.width = 150
        titleColumn.minWidth = 100
        tableView.addTableColumn(titleColumn)

        // Status column
        let statusColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("status"))
        statusColumn.title = "Status"
        statusColumn.width = 120
        statusColumn.minWidth = 80
        tableView.addTableColumn(statusColumn)

        // Progress column
        let progressColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("progress"))
        progressColumn.title = "Progress"
        progressColumn.width = 100
        progressColumn.minWidth = 80
        tableView.addTableColumn(progressColumn)

        // Duration column
        let durationColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("duration"))
        durationColumn.title = "Duration"
        durationColumn.width = 80
        durationColumn.minWidth = 60
        tableView.addTableColumn(durationColumn)

        // Output column
        let outputColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("output"))
        outputColumn.title = "Output Directory"
        outputColumn.width = 200
        outputColumn.minWidth = 150
        tableView.addTableColumn(outputColumn)

        // Files column
        let filesColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("files"))
        filesColumn.title = "Output Files"
        filesColumn.width = 100
        filesColumn.minWidth = 80
        tableView.addTableColumn(filesColumn)
    }

    private func setupUI() {
        // Create UI elements programmatically if not using XIB
        if statusLabel == nil {
            createUIElements()
        }

        updateStatusLabel()
        updateButtons()
    }

    private func createUIElements() {
        guard let contentView = window?.contentView else { return }

        // Create scroll view for table
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true

        let tableView = NSTableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.headerView = NSTableHeaderView()
        scrollView.documentView = tableView
        queueTableView = tableView

        // Create status label
        let statusLbl = NSTextField()
        statusLbl.translatesAutoresizingMaskIntoConstraints = false
        statusLbl.isEditable = false
        statusLbl.isBezeled = false
        statusLbl.drawsBackground = false
        statusLbl.font = NSFont.systemFont(ofSize: 12)
        statusLbl.textColor = .secondaryLabelColor
        statusLabel = statusLbl

        // Create buttons
        let clearBtn = NSButton()
        clearBtn.translatesAutoresizingMaskIntoConstraints = false
        clearBtn.title = "Clear Completed"
        clearBtn.target = self
        clearBtn.action = #selector(clearCompleted(_:))
        clearCompletedButton = clearBtn

        let cancelBtn = NSButton()
        cancelBtn.translatesAutoresizingMaskIntoConstraints = false
        cancelBtn.title = "Cancel All"
        cancelBtn.target = self
        cancelBtn.action = #selector(cancelAll(_:))
        cancelAllButton = cancelBtn

        let refreshBtn = NSButton()
        refreshBtn.translatesAutoresizingMaskIntoConstraints = false
        refreshBtn.title = "Refresh"
        refreshBtn.target = self
        refreshBtn.action = #selector(refresh(_:))
        refreshButton = refreshBtn

        // Add to content view
        contentView.addSubview(scrollView)
        contentView.addSubview(statusLbl)
        contentView.addSubview(clearBtn)
        contentView.addSubview(cancelBtn)
        contentView.addSubview(refreshBtn)

        // Setup constraints
        NSLayoutConstraint.activate([
            // Table view
            scrollView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            scrollView.bottomAnchor.constraint(equalTo: statusLbl.topAnchor, constant: -20),

            // Status label
            statusLbl.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            statusLbl.bottomAnchor.constraint(equalTo: clearBtn.topAnchor, constant: -10),

            // Buttons
            clearBtn.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            clearBtn.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),

            cancelBtn.leadingAnchor.constraint(equalTo: clearBtn.trailingAnchor, constant: 10),
            cancelBtn.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),

            refreshBtn.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            refreshBtn.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
    }

    // MARK: - Actions

    @objc private func clearCompleted(_ sender: NSButton) {
        conversionQueue.clearCompletedJobs()
    }

    @objc private func cancelAll(_ sender: NSButton) {
        let alert = NSAlert()
        alert.messageText = "Cancel All Jobs"
        alert.informativeText = "Are you sure you want to cancel all pending jobs?"
        alert.addButton(withTitle: "Cancel Jobs")
        alert.addButton(withTitle: "Keep Jobs")
        alert.alertStyle = .warning

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            conversionQueue.cancelAllJobs()
        }
    }

    @objc private func cancelSelectedJobs(_ sender: NSButton) {
        guard let tableView = queueTableView else { return }
        let selectedRows = tableView.selectedRowIndexes

        guard !selectedRows.isEmpty else {
            let alert = NSAlert()
            alert.messageText = "No Selection"
            alert.informativeText = "Please select one or more jobs to cancel."
            alert.runModal()
            return
        }

        for row in selectedRows {
            if row < jobs.count {
                conversionQueue.cancelJob(id: jobs[row].id)
            }
        }
    }

    @objc private func refresh(_ sender: NSButton) {
        refreshQueueData()
    }

    @objc private func showJobDetails(_ sender: NSButton) {
        guard let tableView = queueTableView else { return }
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0, selectedRow < jobs.count else { return }

        let job = jobs[selectedRow]
        showJobDetailsAlert(for: job)
    }

    // MARK: - Data Management

    private func refreshQueueData() {
        jobs = conversionQueue.getAllJobs()
        queueTableView?.reloadData()
        updateStatusLabel()
        updateButtons()
    }

    private func updateStatusLabel() {
        let status = conversionQueue.getQueueStatus()
        let extracting = conversionQueue.getExtractingCount()
        let converting = conversionQueue.getConvertingCount()
        let completed = conversionQueue.getCompletedCount()
        let failed = conversionQueue.getFailedCount()

        let statusText = "Total: \(status.total) | Pending: \(status.pending) | " +
                        "Extracting: \(extracting) | Converting: \(converting) | " +
                        "Completed: \(completed) | Failed: \(failed)"
        statusLabel?.stringValue = statusText
    }

    private func updateButtons() {
        let hasCompletedJobs = jobs.contains { job in
            switch job.status {
            case .completed, .failed, .cancelled:
                return true
            default:
                return false
            }
        }

        let hasPendingJobs = jobs.contains { job in
            switch job.status {
            case .pending:
                return true
            default:
                return false
            }
        }

        clearCompletedButton?.isEnabled = hasCompletedJobs
        cancelAllButton?.isEnabled = hasPendingJobs
    }

    private func showJobDetailsAlert(for job: ConversionQueue.ConversionJob) {
        let alert = NSAlert()
        alert.messageText = "Job Details: \(job.discTitle)"

        var details = """
        ID: \(job.id.uuidString)
        Source: \(job.sourcePath)
        Output: \(job.outputDirectory)
        Status: \(job.statusDescription)
        Progress: \(Int(job.progress * 100))%
        Duration: \(job.formattedDuration)
        Media Type: \(job.mediaType)
        """

        if !job.outputFiles.isEmpty {
            details += "\n\nOutput Files:\n"
            for file in job.outputFiles {
                details += "• \(file)\n"
            }
        }

        alert.informativeText = details
        alert.addButton(withTitle: "OK")

        if case .failed = job.status {
            alert.addButton(withTitle: "Show Error Details")
        }

        let response = alert.runModal()

        if response == .alertSecondButtonReturn {
            if case .failed(let error) = job.status {
                showErrorDetails(error: error)
            }
        }
    }

    private func showErrorDetails(error: Error) {
        let alert = NSAlert()
        alert.messageText = "Error Details"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .critical
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    // MARK: - Timer Management

    private func startRefreshTimer() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.refreshQueueData()
        }
    }

    private func stopRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}

// MARK: - NSTableViewDataSource

extension QueueWindowController: NSTableViewDataSource {

    func numberOfRows(in tableView: NSTableView) -> Int {
        return jobs.count
    }
}

// MARK: - NSTableViewDelegate

extension QueueWindowController: NSTableViewDelegate {

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < jobs.count else { return nil }

        let job = jobs[row]
        let identifier = tableColumn?.identifier

        let cellView = NSTableCellView()
        let textField = NSTextField()
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.isEditable = false
        textField.isBezeled = false
        textField.drawsBackground = false
        textField.font = NSFont.systemFont(ofSize: 12)

        cellView.addSubview(textField)
        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 4),
            textField.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -4),
            textField.centerYAnchor.constraint(equalTo: cellView.centerYAnchor)
        ])

        switch identifier?.rawValue {
        case "title":
            textField.stringValue = job.discTitle

        case "status":
            textField.stringValue = job.statusDescription

            // Color code status
            switch job.status {
            case .pending:
                textField.textColor = .systemBlue
            case .extracting:
                textField.textColor = .systemOrange
            case .extracted:
                textField.textColor = .systemPurple
            case .converting:
                textField.textColor = .systemYellow
            case .completed:
                textField.textColor = .systemGreen
            case .failed:
                textField.textColor = .systemRed
            case .cancelled:
                textField.textColor = .systemGray
            }

        case "progress":
            if job.progress > 0 {
                // Create progress bar
                let progressBar = NSProgressIndicator()
                progressBar.translatesAutoresizingMaskIntoConstraints = false
                progressBar.style = .bar
                progressBar.isIndeterminate = false
                progressBar.doubleValue = job.progress * 100
                progressBar.minValue = 0
                progressBar.maxValue = 100

                cellView.addSubview(progressBar)
                NSLayoutConstraint.activate([
                    progressBar.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 4),
                    progressBar.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -4),
                    progressBar.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
                    progressBar.heightAnchor.constraint(equalToConstant: 16)
                ])

                return cellView
            } else {
                textField.stringValue = "-"
            }

        case "duration":
            textField.stringValue = job.formattedDuration

        case "output":
            textField.stringValue = URL(fileURLWithPath: job.outputDirectory).lastPathComponent

        case "files":
            textField.stringValue = "\(job.outputFiles.count) files"

        default:
            textField.stringValue = ""
        }

        cellView.textField = textField
        return cellView
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        return true
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        // Could add context menu or additional actions here
    }
}

// MARK: - ConversionQueueDelegate

extension QueueWindowController: ConversionQueueDelegate {

    func queueDidUpdateJobs(_ jobs: [ConversionQueue.ConversionJob]) {
        DispatchQueue.main.async {
            self.jobs = jobs
            self.queueTableView?.reloadData()
            self.updateStatusLabel()
            self.updateButtons()
        }
    }

    func queueDidStartExtraction(jobId: UUID) {
        // Optional: Show notification or update specific UI
    }

    func queueDidCompleteExtraction(jobId: UUID) {
        // Optional: Show notification that disc can be ejected
        DispatchQueue.main.async {
            if let job = self.jobs.first(where: { $0.id == jobId }) {
                let content = UNMutableNotificationContent()
                content.title = "Disc Ready for Ejection"
                content.body = "Disc '\(job.discTitle)' has been read and can now be ejected"
                content.sound = UNNotificationSound.default
                
                let request = UNNotificationRequest(identifier: "extraction-complete-\(jobId.uuidString)", content: content, trigger: nil)
                UNUserNotificationCenter.current().add(request)
            }
        }
    }

    func queueDidFailExtraction(jobId: UUID, error: Error) {
        // Optional: Show error notification
    }

    func queueDidStartConversion(jobId: UUID) {
        // Optional: Show notification
    }

    func queueDidCompleteConversion(jobId: UUID, outputFiles: [String]) {
        // Optional: Show completion notification
        DispatchQueue.main.async {
            if let job = self.jobs.first(where: { $0.id == jobId }) {
                let content = UNMutableNotificationContent()
                content.title = "Conversion Complete"
                content.body = "'\(job.discTitle)' has been converted to \(outputFiles.count) MKV file(s)"
                content.sound = UNNotificationSound.default
                
                let request = UNNotificationRequest(identifier: "conversion-complete-\(jobId.uuidString)", content: content, trigger: nil)
                UNUserNotificationCenter.current().add(request)
            }
        }
    }

    func queueDidFailConversion(jobId: UUID, error: Error) {
        // Optional: Show error notification
    }

    func queueDidUpdateConversionStatus(jobId: UUID, status: String) {
        // Optional: Could show detailed status updates
    }

    func queueDidUpdateConversionProgress(jobId: UUID, progress: Double) {
        // Real-time progress updates are handled by the refresh timer
    }
}
