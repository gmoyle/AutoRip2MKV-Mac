import Foundation

/// Routes a completed rip folder into the correct Plex library root (Movies or
/// TV Shows) based on its content type.
///
/// Two paths:
///  - **Auto**: after a rip, if content routing is on and the classifier is
///    confident (and auto-route is enabled), the folder moves straight to the
///    right root. Otherwise the rip is enqueued for the user to confirm later.
///    Either way the rip itself never blocks.
///  - **Manual**: the review UI calls `route(folder:to:)` when the user confirms
///    a queued item's Movie/TV choice.
enum ContentRouter {

    /// Confidence at or above this is considered safe to auto-route without asking.
    static let autoRouteConfidenceThreshold: Double = 0.8

    enum RouteError: LocalizedError {
        case rootNotConfigured(ContentType)
        case moveFailed(String)

        var errorDescription: String? {
            switch self {
            case .rootNotConfigured(let type):
                return "No destination folder is set for \(type.displayName)s."
            case .moveFailed(let msg):
                return "Couldn't move the ripped folder: \(msg)"
            }
        }
    }

    /// Decide what to do with a just-completed rip. Returns a short status string
    /// for the log. Never throws for the "needs review" case — it enqueues.
    ///
    /// - Parameters:
    ///   - folderPath: the organized rip folder to route.
    ///   - discName: volume label for display in the review queue.
    ///   - discIdentity: stable disc identity (see [[DiscIdentity]]); stored on any
    ///     queued item so the skip-already-ripped check recognizes a disc that's
    ///     still awaiting review and doesn't re-rip it on re-insert.
    ///   - titleDurationsSeconds: enumerated title durations for classification.
    @discardableResult
    static func handleCompletedRip(folderPath: String,
                                   discName: String,
                                   discIdentity: String? = nil,
                                   titleDurationsSeconds: [Int],
                                   settings: SettingsManager = .shared,
                                   queue: PendingRoutingQueue = .shared) -> String {
        guard settings.contentRoutingEnabled else {
            return "Content routing is off — leaving rip in place."
        }

        let classification = ContentTypeClassifier.classify(titleDurationsSeconds: titleDurationsSeconds)

        // High-confidence, known type, auto-route enabled → move now.
        if settings.autoRouteHighConfidence,
           classification.type != .unknown,
           classification.confidence >= autoRouteConfidenceThreshold {
            do {
                let dest = try route(folderPath: folderPath, to: classification.type,
                                     discIdentity: discIdentity, settings: settings)
                return "Auto-routed \(discName) to \(classification.type.displayName)s: \(dest)"
            } catch {
                // Fall through to queueing so a misconfigured root doesn't lose the rip.
                queue.enqueue(PendingRouting(
                    discName: discName, discIdentity: discIdentity, folderPath: folderPath,
                    guessedType: classification.type, confidence: classification.confidence))
                return "Couldn't auto-route \(discName) (\(error.localizedDescription)) — queued for review."
            }
        }

        // Ambiguous or auto-route disabled → defer to the user's review queue.
        queue.enqueue(PendingRouting(
            discName: discName, discIdentity: discIdentity, folderPath: folderPath,
            guessedType: classification.type, confidence: classification.confidence))
        return "Queued \(discName) for Movie/TV review (guess: \(classification.type.displayName), "
            + "confidence \(Int(classification.confidence * 100))%)."
    }

    /// Move `folderPath` into the configured root for `type`. Returns the
    /// destination path. Library clients (Plex, the NAS indexer, Windows) never
    /// see a half-copied file: a cross-volume move copies under a hidden name
    /// and renames into place.
    ///
    /// A re-rip of the same disc (the library folder's recorded rip has the
    /// same `discIdentity`) replaces that rip's files in place rather than
    /// creating a "(2)" duplicate; anything else in the folder (artwork, NAS
    /// thumbnails) is left alone. A different disc with the same folder name
    /// still gets a " (2)" suffix.
    @discardableResult
    static func route(folderPath: String,
                      to type: ContentType,
                      discIdentity: String? = nil,
                      settings: SettingsManager = .shared,
                      fileManager: FileManager = .default,
                      history: RipHistoryStore = .shared) throws -> String {
        let root: String
        switch type {
        case .movie: root = settings.moviesRootDirectory
        case .tvShow: root = settings.tvShowsRootDirectory
        case .unknown: throw RouteError.rootNotConfigured(.unknown)
        }
        guard !root.isEmpty else { throw RouteError.rootNotConfigured(type) }

        try? fileManager.createDirectory(atPath: root, withIntermediateDirectories: true)

        let folderName = (folderPath as NSString).lastPathComponent
        var destination = (root as NSString).appendingPathComponent(folderName)

        do {
            if fileManager.fileExists(atPath: destination) {
                if let identity = discIdentity,
                   let previous = history.entry(forIdentity: identity),
                   standardized(previous.outputLocation) == standardized(destination) {
                    try replaceFiles(from: folderPath, into: destination, fileManager: fileManager)
                    recordMove(from: folderPath, to: destination)
                    history.updateOutputLocation(from: folderPath, to: destination)
                    return destination
                }
                // Someone else's folder of the same name: don't clobber it.
                destination = uniqueDestination(base: destination, fileManager: fileManager)
            }
            try moveFolder(folderPath, to: destination, fileManager: fileManager)
        } catch let error as RouteError {
            throw error
        } catch {
            throw RouteError.moveFailed(error.localizedDescription)
        }

        // Record where this folder went. The rip registry may be written before
        // OR after routing depending on the path (for Blu-ray, routing runs first),
        // so we both update any existing entry now and remember the move so a
        // later registry write can resolve the staging path to its final home.
        recordMove(from: folderPath, to: destination)
        RipHistoryStore.shared.updateOutputLocation(from: folderPath, to: destination)

        return destination
    }

    /// Maps a just-routed staging folder path → its final library location, so a
    /// registry write that happens after the move can record the real path.
    private static var recentMoves: [String: String] = [:]
    private static let recentMovesLock = NSLock()

    private static func recordMove(from source: String, to destination: String) {
        recentMovesLock.lock(); defer { recentMovesLock.unlock() }
        recentMoves[source] = destination
    }

    /// Final location a staging path was routed to, if routing moved it. Consumed
    /// (removed) on read so the map doesn't grow unbounded.
    static func finalLocation(forStagingPath path: String) -> String? {
        recentMovesLock.lock(); defer { recentMovesLock.unlock() }
        return recentMoves.removeValue(forKey: path)
    }

    private static func standardized(_ path: String) -> String {
        ((path as NSString).standardizingPath as NSString).resolvingSymlinksInPath
    }

    private static func isSameVolume(_ a: String, _ b: String, fileManager: FileManager) -> Bool {
        let device = { (path: String) in (try? fileManager.attributesOfItem(atPath: path))?[.systemNumber] as? Int }
        guard let x = device(a), let y = device(b) else { return false }
        return x == y
    }

    /// Rename when possible; across volumes, copy to a hidden sibling of the
    /// destination, rename that into place, then remove the source.
    private static func moveFolder(_ source: String, to destination: String, fileManager: FileManager) throws {
        let parent = (destination as NSString).deletingLastPathComponent
        if isSameVolume(source, parent, fileManager: fileManager) {
            try fileManager.moveItem(atPath: source, toPath: destination)
            return
        }
        let partial = (parent as NSString).appendingPathComponent(
            ".\((destination as NSString).lastPathComponent).partial-\(UUID().uuidString.prefix(8))")
        do {
            try fileManager.copyItem(atPath: source, toPath: partial)
            try fileManager.moveItem(atPath: partial, toPath: destination)
        } catch {
            try? fileManager.removeItem(atPath: partial)
            throw error
        }
        try? fileManager.removeItem(atPath: source)
    }

    /// Re-rip of the same disc: put each of the new rip's files into the
    /// existing library folder, replacing same-named ones. Each file lands via
    /// a hidden temporary name and a rename; the old file is only removed once
    /// the new one is fully copied.
    private static func replaceFiles(from source: String, into destination: String,
                                     fileManager: FileManager) throws {
        let names = try fileManager.contentsOfDirectory(atPath: source).filter { $0 != ".DS_Store" }
        for name in names {
            let from = (source as NSString).appendingPathComponent(name)
            let to = (destination as NSString).appendingPathComponent(name)
            let partial = (destination as NSString).appendingPathComponent(
                ".\(name).partial-\(UUID().uuidString.prefix(8))")
            do {
                try fileManager.copyItem(atPath: from, toPath: partial)
                if fileManager.fileExists(atPath: to) {
                    // replaceItemAt isn't supported on every network filesystem;
                    // the new copy is complete, so swapping by hand is safe.
                    do {
                        _ = try fileManager.replaceItemAt(URL(fileURLWithPath: to),
                                                          withItemAt: URL(fileURLWithPath: partial))
                    } catch {
                        try fileManager.removeItem(atPath: to)
                        try fileManager.moveItem(atPath: partial, toPath: to)
                    }
                } else {
                    try fileManager.moveItem(atPath: partial, toPath: to)
                }
            } catch {
                try? fileManager.removeItem(atPath: partial)
                throw error
            }
        }
        try? fileManager.removeItem(atPath: source)
    }

    /// Append " (2)", " (3)", … until the path is free.
    private static func uniqueDestination(base: String, fileManager: FileManager) -> String {
        var n = 2
        while true {
            let candidate = "\(base) (\(n))"
            if !fileManager.fileExists(atPath: candidate) { return candidate }
            n += 1
        }
    }
}
