import Cocoa

/// Non-blocking review UI for pending Movie/TV routing decisions. The user opens
/// this when they return to the app; ripping never waits on it. Each row shows a
/// completed rip with a Movie/TV toggle pre-set to the classifier's guess. The
/// user can accept all guesses at once or override individually, then apply —
/// which atomically moves each folder to its library root and drains the queue.
final class RoutingReviewWindowController: NSWindowController {

    private let queue = PendingRoutingQueue.shared
    private var items: [PendingRouting] = []
    /// Per-item chosen type (defaults to the guess), keyed by pending id.
    private var choices: [UUID: ContentType] = [:]

    private var tableView: NSTableView!
    private var statusLabel: NSTextField!

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 420),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered, defer: false)
        window.title = "Review Rips — Movie or TV Show"
        window.center()
        window.minSize = NSSize(width: 520, height: 300)
        self.init(window: window)
        window.isReleasedWhenClosed = false
        reload()
        setupUI()
        NotificationCenter.default.addObserver(
            self, selector: #selector(queueChanged),
            name: PendingRoutingQueue.didChangeNotification, object: nil)
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    @objc private func queueChanged() {
        DispatchQueue.main.async { [weak self] in
            self?.reload()
            self?.tableView?.reloadData()
            self?.updateStatus()
        }
    }

    private func reload() {
        queue.pruneMissingFolders()
        items = queue.items
        // Seed choices from guesses (falling back to .movie for unknown so a
        // toggle always has a concrete position).
        for item in items where choices[item.id] == nil {
            choices[item.id] = item.guessedType == .unknown ? .movie : item.guessedType
        }
    }

    private func setupUI() {
        guard let content = window?.contentView else { return }

        statusLabel = NSTextField(labelWithString: "")
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(statusLabel)

        let scroll = NSScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder

        tableView = NSTableView()
        tableView.dataSource = self
        tableView.delegate = self
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.rowHeight = 32

        let discCol = NSTableColumn(identifier: .init("disc"))
        discCol.title = "Disc"
        discCol.width = 260
        tableView.addTableColumn(discCol)

        let guessCol = NSTableColumn(identifier: .init("guess"))
        guessCol.title = "Guess"
        guessCol.width = 120
        tableView.addTableColumn(guessCol)

        let choiceCol = NSTableColumn(identifier: .init("choice"))
        choiceCol.title = "Route as"
        choiceCol.width = 180
        tableView.addTableColumn(choiceCol)

        scroll.documentView = tableView
        content.addSubview(scroll)

        let acceptAll = NSButton(title: "Accept All Guesses", target: self,
                                 action: #selector(acceptAllGuesses))
        acceptAll.translatesAutoresizingMaskIntoConstraints = false

        let apply = NSButton(title: "Apply", target: self, action: #selector(applyChoices))
        apply.translatesAutoresizingMaskIntoConstraints = false
        apply.keyEquivalent = "\r"

        content.addSubview(acceptAll)
        content.addSubview(apply)

        NSLayoutConstraint.activate([
            statusLabel.topAnchor.constraint(equalTo: content.topAnchor, constant: 12),
            statusLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            statusLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),

            scroll.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 10),
            scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            scroll.bottomAnchor.constraint(equalTo: apply.topAnchor, constant: -12),

            acceptAll.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            acceptAll.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -16),

            apply.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            apply.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -16),
        ])

        updateStatus()
    }

    private func updateStatus() {
        let n = items.count
        statusLabel.stringValue = n == 0
            ? "No rips awaiting routing. New rips will appear here."
            : "\(n) rip\(n == 1 ? "" : "s") awaiting a Movie/TV Show decision."
    }

    @objc private func acceptAllGuesses() {
        for item in items {
            choices[item.id] = item.guessedType == .unknown ? .movie : item.guessedType
        }
        tableView.reloadData()
    }

    @objc private func applyChoices() {
        var moved = 0
        var failures: [String] = []
        for item in items {
            let type = choices[item.id] ?? .movie
            do {
                _ = try ContentRouter.route(folderPath: item.folderPath, to: type)
                queue.remove(id: item.id)
                choices[item.id] = nil
                moved += 1
            } catch {
                failures.append("\(item.discName): \(error.localizedDescription)")
            }
        }
        reload()
        tableView.reloadData()
        updateStatus()

        if !failures.isEmpty {
            let alert = NSAlert()
            alert.messageText = "Some rips couldn't be routed"
            alert.informativeText = failures.joined(separator: "\n")
            alert.alertStyle = .warning
            alert.runModal()
        } else if moved > 0, items.isEmpty {
            window?.performClose(nil)
        }
    }

    /// Row's Movie/TV segmented control changed.
    @objc private func choiceChanged(_ sender: NSSegmentedControl) {
        let row = sender.tag
        guard row >= 0, row < items.count else { return }
        choices[items[row].id] = sender.selectedSegment == 0 ? .movie : .tvShow
    }
}

extension RoutingReviewWindowController: NSTableViewDataSource, NSTableViewDelegate {

    func numberOfRows(in tableView: NSTableView) -> Int { items.count }

    func tableView(_ tableView: NSTableView,
                   viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < items.count, let id = tableColumn?.identifier.rawValue else { return nil }
        let item = items[row]

        switch id {
        case "disc":
            return NSTextField(labelWithString: item.discName)
        case "guess":
            let pct = Int(item.confidence * 100)
            let text = item.guessedType == .unknown
                ? "— (unsure)"
                : "\(item.guessedType.displayName) (\(pct)%)"
            let label = NSTextField(labelWithString: text)
            label.textColor = item.confidence >= ContentRouter.autoRouteConfidenceThreshold
                ? .labelColor : .secondaryLabelColor
            return label
        case "choice":
            let seg = NSSegmentedControl(labels: ["Movie", "TV Show"],
                                         trackingMode: .selectOne,
                                         target: self, action: #selector(choiceChanged(_:)))
            seg.tag = row
            seg.selectedSegment = (choices[item.id] ?? .movie) == .movie ? 0 : 1
            return seg
        default:
            return nil
        }
    }
}
