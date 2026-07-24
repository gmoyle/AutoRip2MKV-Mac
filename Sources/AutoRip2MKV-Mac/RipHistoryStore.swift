import Foundation

/// A record of one disc that has been ripped. Stored centrally (independent of
/// where the output files live), so "have I ripped this disc?" no longer depends
/// on scanning movie folders — which breaks when content routing moves a rip
/// into a Plex library root, or the user reorganizes their library.
struct RipHistoryEntry: Codable, Equatable {
    /// Stable identity of the disc: volume label + content fingerprint.
    let discIdentity: String
    /// Disc volume label at rip time, for display.
    let volumeName: String
    /// Resolved title (e.g. "Firefly" / "Hangmen (2017)") if known, else the label.
    let title: String
    /// Fingerprint of the settings used, so a settings change re-rips.
    let settingsFingerprint: [String: String]
    /// Where the finished rip was written (final location, for reference/reveal).
    var outputLocation: String
    /// When the rip completed.
    let completedAt: Date
}

/// Central, persistent registry of ripped discs. One JSON file in Application
/// Support, keyed by disc identity. This is the source of truth for the
/// "skip already-ripped discs" feature.
final class RipHistoryStore {

    static let shared = RipHistoryStore()

    private let fileURL: URL
    private let lock = NSLock()

    /// - Parameter fileURL: override for tests; defaults to the app-support path.
    init(fileURL: URL? = nil) {
        if let fileURL = fileURL {
            self.fileURL = fileURL
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("AutoRip2MKV-Mac", isDirectory: true)
            try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
            self.fileURL = base.appendingPathComponent("rip_history.json")
        }
    }

    /// All entries, keyed by disc identity.
    private func load() -> [String: RipHistoryEntry] {
        guard let data = try? Data(contentsOf: fileURL) else { return [:] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([String: RipHistoryEntry].self, from: data)) ?? [:]
    }

    private func save(_ entries: [String: RipHistoryEntry]) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(entries) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    /// Record (or update) a completed rip.
    func record(_ entry: RipHistoryEntry) {
        lock.lock(); defer { lock.unlock() }
        var all = load()
        all[entry.discIdentity] = entry
        save(all)
    }

    /// The recorded rip for a disc identity, if any.
    func entry(forIdentity identity: String) -> RipHistoryEntry? {
        lock.lock(); defer { lock.unlock() }
        return load()[identity]
    }

    /// The recorded rip for a disc, matched on the content fingerprint rather than
    /// the exact identity string. macOS can remount the same physical disc under a
    /// suffixed volume path (e.g. "/Volumes/FIREFLY 1"), which changes the label
    /// portion of the identity but not the fingerprint after "#". Prefers an exact
    /// key hit, then falls back to any entry sharing the fingerprint. See
    /// [[DiscIdentity]].fingerprintComponent.
    func entry(matchingFingerprintOf identity: String) -> RipHistoryEntry? {
        lock.lock(); defer { lock.unlock() }
        let all = load()
        if let exact = all[identity] { return exact }
        let target = DiscIdentity.fingerprintComponent(of: identity)
        return all.first { DiscIdentity.fingerprintComponent(of: $0.key) == target }?.value
    }

    /// True if this disc was ripped with settings matching `settingsFingerprint`.
    /// A settings change (different fingerprint) reports false so the disc re-rips.
    func isAlreadyRipped(identity: String, settingsFingerprint: [String: String]) -> Bool {
        guard let entry = entry(forIdentity: identity) else { return false }
        return entry.settingsFingerprint == settingsFingerprint
    }

    /// Update the stored output location for an identity (e.g. after routing moves
    /// the folder), without changing the rest of the record.
    func updateOutputLocation(identity: String, to location: String) {
        lock.lock(); defer { lock.unlock() }
        var all = load()
        guard var entry = all[identity] else { return }
        entry.outputLocation = location
        all[identity] = entry
        save(all)
    }

    /// Update whichever entry currently points at `oldLocation` to `newLocation`.
    /// Used by content routing, which knows the folder path it moved but not the
    /// disc identity. No-op if no entry matches (e.g. routing off, or the rip
    /// wasn't recorded under that path).
    func updateOutputLocation(from oldLocation: String, to newLocation: String) {
        lock.lock(); defer { lock.unlock() }
        var all = load()
        guard let key = all.first(where: { $0.value.outputLocation == oldLocation })?.key else { return }
        all[key]?.outputLocation = newLocation
        save(all)
    }

    /// Remove an entry (e.g. user wants to force a re-rip permanently).
    func remove(identity: String) {
        lock.lock(); defer { lock.unlock() }
        var all = load()
        all.removeValue(forKey: identity)
        save(all)
    }
}
