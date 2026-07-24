import Foundation

/// One completed rip awaiting a Movie/TV Show routing decision. Created when a
/// rip finishes but the content type wasn't confidently auto-routed, so the
/// choice is deferred to the user's review — without ever blocking further rips.
struct PendingRouting: Codable, Equatable, Identifiable {
    let id: UUID
    /// Disc volume label at rip time (e.g. "FIREFLYUS_D1"), for display.
    let discName: String
    /// Absolute path to the organized rip folder currently on disk (in the
    /// original output location) that still needs to be moved to a library root.
    let folderPath: String
    /// The classifier's guess, used to pre-select the toggle in review.
    let guessedType: ContentType
    /// Classifier confidence 0…1, for display/ordering.
    let confidence: Double
    /// When the rip completed.
    let createdAt: Date

    init(id: UUID = UUID(), discName: String, folderPath: String,
         guessedType: ContentType, confidence: Double, createdAt: Date = Date()) {
        self.id = id
        self.discName = discName
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
