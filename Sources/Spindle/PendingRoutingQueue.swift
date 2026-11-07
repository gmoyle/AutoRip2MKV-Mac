import Foundation

/// One completed rip awaiting a Movie/TV Show routing decision. Created when a
/// rip finishes but the content type wasn't confidently auto-routed, so the
/// choice is deferred to the user's review — without ever blocking further rips.
struct PendingRouting: Codable, Equatable, Identifiable {
    let id: UUID
    /// Disc volume label at rip time (e.g. "FIREFLYUS_D1"), for display.
    let discName: String
    /// Stable disc identity ("<label>#<fingerprint>", see [[DiscIdentity]]) of the
    /// disc this rip came from. Lets the skip-already-ripped check recognize a disc
    /// that's still awaiting a routing decision, so re-inserting it doesn't re-rip.
    /// Optional so queue entries persisted before this field decode without loss.
    let discIdentity: String?
    /// Absolute path to the organized rip folder currently on disk (in the
    /// original output location) that still needs to be moved to a library root.
    let folderPath: String
    /// The classifier's guess, used to pre-select the toggle in review.
    let guessedType: ContentType
    /// Classifier confidence 0…1, for display/ordering.
    let confidence: Double
    /// When the rip completed.
    let createdAt: Date

    init(id: UUID = UUID(), discName: String, discIdentity: String? = nil,
         folderPath: String, guessedType: ContentType, confidence: Double,
         createdAt: Date = Date()) {
        self.id = id
        self.discName = discName
        self.discIdentity = discIdentity
        self.folderPath = folderPath
        self.guessedType = guessedType
        self.confidence = confidence
        self.createdAt = createdAt
    }
}

/// Persistent, thread-safe queue of pending routing decisions. Survives app
/// restarts (JSON in UserDefaults) so a ripped folder is never orphaned if the
/// user quits before reviewing. Rips append here and return immediately; the
/// review UI drains it.
final class PendingRoutingQueue {

    static let shared = PendingRoutingQueue()

    /// Posted whenever the queue changes, so any open review UI / badge refreshes.
    static let didChangeNotification = Notification.Name("PendingRoutingQueueDidChange")

    /// UserDefaults key for the persisted queue.
    static let storageKey = "pendingRoutings"

    private let defaults: UserDefaults
    private let key: String
    private let lock = NSLock()

    init(defaults: UserDefaults = .standard, key: String = PendingRoutingQueue.storageKey) {
        self.defaults = defaults
        self.key = key
    }

    /// All pending items, oldest first.
    var items: [PendingRouting] {
        lock.lock(); defer { lock.unlock() }
        return load()
    }

    var count: Int { items.count }

    /// True if a rip of the disc with `identity` is already awaiting a routing
    /// decision. Matching is tolerant of volume-label drift: macOS may remount the
    /// same disc under a suffixed path (e.g. "/Volumes/FIREFLY 1"), which changes
    /// the label portion of the identity but not its content fingerprint — so we
    /// compare on the fingerprint after the "#" when present. This is what lets a
    /// disc that's still in the Review Rips queue be recognized on re-insert instead
    /// of being ripped again.
    func containsDisc(identity: String) -> Bool {
        let target = DiscIdentity.fingerprintComponent(of: identity)
        return items.contains { item in
            guard let stored = item.discIdentity else { return false }
            return DiscIdentity.fingerprintComponent(of: stored) == target
        }
    }

    /// Append a rip awaiting a decision.
    func enqueue(_ item: PendingRouting) {
        lock.lock()
        var all = load()
        all.append(item)
        save(all)
        lock.unlock()
        notifyChanged()
    }

    /// Remove an item once its routing has been carried out (or discarded).
    func remove(id: UUID) {
        lock.lock()
        var all = load()
        all.removeAll { $0.id == id }
        save(all)
        lock.unlock()
        notifyChanged()
    }

    /// Drop entries whose folder no longer exists on disk (moved/deleted out of
    /// band), so the queue can't accumulate dead rows. Returns the count removed.
    @discardableResult
    func pruneMissingFolders(fileManager: FileManager = .default) -> Int {
        lock.lock()
        var all = load()
        let before = all.count
        all.removeAll { !fileManager.fileExists(atPath: $0.folderPath) }
        let removed = before - all.count
        if removed > 0 { save(all) }
        lock.unlock()
        if removed > 0 { notifyChanged() }
        return removed
    }

    // MARK: - Persistence

    private func load() -> [PendingRouting] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([PendingRouting].self, from: data)) ?? []
    }

    private func save(_ items: [PendingRouting]) {
        if let data = try? JSONEncoder().encode(items) {
            defaults.set(data, forKey: key)
        }
    }

    private func notifyChanged() {
        NotificationCenter.default.post(name: Self.didChangeNotification, object: self)
    }
}
