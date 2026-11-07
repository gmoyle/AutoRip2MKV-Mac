import Cocoa

// MARK: - Embedded Queue Table

extension MainViewController: NSTableViewDataSource, NSTableViewDelegate {

    func numberOfRows(in tableView: NSTableView) -> Int {
        return queueJobs.count
    }

    func tableView(_ tableView: NSTableView,
                   viewFor tableColumn: NSTableColumn?,
                   row: Int) -> NSView? {
        guard row < queueJobs.count, let columnId = tableColumn?.identifier.rawValue else { return nil }
        let job = queueJobs[row]

        let text: String
        switch columnId {
        case "title":
            text = job.discTitle
        case "status":
            text = job.statusDescription
        case "progress":
            switch job.status {
            case .extracting, .converting:
                text = "\(Int(job.progress * 100))%"
            case .completed:
                text = "100%"
            default:
                text = "—"
            }
        case "duration":
            text = job.formattedDuration
        default:
            text = ""
        }

        let cellId = NSUserInterfaceItemIdentifier("queueCell_\(columnId)")
        let cell: NSTableCellView
        if let reused = tableView.makeView(withIdentifier: cellId, owner: nil) as? NSTableCellView {
            cell = reused
        } else {
            cell = NSTableCellView()
            cell.identifier = cellId
            let field = NSTextField(labelWithString: "")
            field.font = NSFont.systemFont(ofSize: 12)
            field.lineBreakMode = .byTruncatingTail
            field.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(field)
            cell.textField = field
            NSLayoutConstraint.activate([
                field.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 2),
                field.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -2),
                field.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
            ])
        }
        cell.textField?.stringValue = text
        if case .failed = job.status, columnId == "status" {
            cell.textField?.textColor = .systemRed
        } else {
            cell.textField?.textColor = .labelColor
        }
        return cell
    }

    // MARK: Context menu

    internal func makeQueueContextMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Cancel Job", action: #selector(queueCancelJob(_:)), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Retry Job", action: #selector(queueRetryJob(_:)), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Reveal in Finder", action: #selector(queueRevealInFinder(_:)), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Remove from List", action: #selector(queueRemoveJob(_:)), keyEquivalent: ""))
        for item in menu.items { item.target = self }
        menu.delegate = self
        return menu
    }

    private var clickedQueueJob: ConversionQueue.ConversionJob? {
        let row = queueTableView.clickedRow
        guard row >= 0, row < queueJobs.count else { return nil }
        return queueJobs[row]
    }

    @objc private func queueCancelJob(_ sender: Any) {
        guard let job = clickedQueueJob else { return }
        conversionQueue.cancelJob(id: job.id)
        appendToLog("Cancelled job: \(job.discTitle)")
    }

    @objc private func queueRetryJob(_ sender: Any) {
        guard let job = clickedQueueJob else { return }
        conversionQueue.retryJob(id: job.id)
        appendToLog("Retrying job: \(job.discTitle)")
    }

    @objc private func queueRevealInFinder(_ sender: Any) {
        guard let job = clickedQueueJob else { return }
        if let file = job.outputFiles.first {
            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: file)])
        } else {
            NSWorkspace.shared.activateFileViewerSelecting(
                [URL(fileURLWithPath: job.outputDirectory)]
            )
        }
    }

    @objc private func queueRemoveJob(_ sender: Any) {
        guard let job = clickedQueueJob else { return }
        conversionQueue.removeJob(id: job.id)
    }
}

extension MainViewController: NSMenuDelegate {

    // Enable only the actions that make sense for the clicked job's state.
    func menuNeedsUpdate(_ menu: NSMenu) {
        guard let job = clickedQueueJob else {
            for item in menu.items { item.isEnabled = false }
            return
        }
        menu.autoenablesItems = false
        for item in menu.items {
            switch item.action {
            case #selector(queueCancelJob(_:)):
                switch job.status {
                case .pending, .extracting, .extracted, .converting: item.isEnabled = true
                default: item.isEnabled = false
                }
            case #selector(queueRetryJob(_:)):
                switch job.status {
                case .failed, .cancelled: item.isEnabled = true
                default: item.isEnabled = false
                }
            case #selector(queueRemoveJob(_:)):
                switch job.status {
                case .extracting, .extracted, .converting: item.isEnabled = false
                default: item.isEnabled = true
                }
            case #selector(queueRevealInFinder(_:)):
                item.isEnabled = true
            default:
                break
            }
        }
    }
}
