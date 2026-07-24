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
                let dest = try route(folderPath: folderPath, to: classification.type, settings: settings)
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

    /// Atomically move `folderPath` into the configured root for `type`. Returns
    /// the destination path. Follows the iCloud-staging rule: a single move so
    /// syncing clients never see a half-copied folder.
    @discardableResult
    static func route(folderPath: String,
                      to type: ContentType,
                      settings: SettingsManager = .shared,
                      fileManager: FileManager = .default) throws -> String {
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

        // If a folder of the same name already exists at the destination, suffix
        // to avoid clobbering a prior rip.
        if fileManager.fileExists(atPath: destination) {
            destination = uniqueDestination(base: destination, fileManager: fileManager)
        }

        // Same-volume rename is atomic; cross-volume moveItem copies then removes
        // (Foundation handles the fallback). Either way the source folder is
        // fully formed before the move, so no partial state is exposed.
        do {
            try fileManager.moveItem(atPath: folderPath, toPath: destination)
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
