import Foundation

/// The app's name and where it keeps its data. Everything that names a folder
/// or file of the app's own goes through here, so a rename is one edit.
enum AppIdentity {
    static let name = "Spindle"
    static let bundleIdentifier = "com.gmoyle.spindle"

    /// The app's names before the rename to Spindle, for the one-time migration.
    enum Legacy {
        static let bundleIdentifier = "com.autorip2mkv.mac"
        static let supportDirectoryName = "AutoRip2MKV-Mac"
    }

    /// `~/Library/Application Support/Spindle`: rip history, logs, downloaded ffmpeg.
    static var supportDirectory: URL {
        supportDirectory(in: FileManager.default.urls(for: .applicationSupportDirectory,
                                                      in: .userDomainMask)[0])
    }

    static func supportDirectory(in applicationSupport: URL) -> URL {
        applicationSupport.appendingPathComponent(name, isDirectory: true)
    }

    /// `~/Library/Caches/Spindle`: local staging for encodes.
    static var cachesDirectory: URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return caches.appendingPathComponent(name, isDirectory: true)
    }

    // MARK: - Migration from AutoRip2MKV

    private static let migratedKey = "migratedFromAutoRip2MKV"

    /// Bring settings, rip history and logs over from AutoRip2MKV on first launch.
    /// Runs before anything else reads settings or opens the log. Safe to call
    /// every launch: it does nothing once it has run.
    static func migrateFromLegacyNameIfNeeded(defaults: UserDefaults = .standard,
                                              fileManager: FileManager = .default) {
        if !defaults.bool(forKey: migratedKey) {
            if let old = defaults.persistentDomain(forName: Legacy.bundleIdentifier) {
                let copied = copyLegacySettings(old, into: defaults)
                NSLog("Spindle: copied \(copied) settings from AutoRip2MKV")
            }
            defaults.set(true, forKey: migratedKey)
        }

        // Not tied to the flag: whenever the old folder is still there, merge
        // whatever it holds that Spindle's folder doesn't have yet.
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        if let moved = moveLegacySupportDirectory(in: appSupport, fileManager: fileManager) {
            NSLog("Spindle: moved app data from \(moved.path)")
        }
    }

    /// Copy each old setting the new domain doesn't already have. Returns how many.
    @discardableResult
    static func copyLegacySettings(_ old: [String: Any], into defaults: UserDefaults) -> Int {
        var copied = 0
        for (key, value) in old where defaults.object(forKey: key) == nil {
            defaults.set(value, forKey: key)
            copied += 1
        }
        return copied
    }

    /// Move `AutoRip2MKV-Mac` in Application Support into `Spindle`. If `Spindle`
    /// already exists (a test run or an earlier launch created its Logs folder),
    /// each item it doesn't have is moved in; nothing in `Spindle` is overwritten.
    /// The old folder is removed once empty. Returns the old folder's URL if
    /// anything was moved.
    @discardableResult
    static func moveLegacySupportDirectory(in applicationSupport: URL,
                                           fileManager: FileManager = .default) -> URL? {
        let old = applicationSupport.appendingPathComponent(Legacy.supportDirectoryName, isDirectory: true)
        let new = supportDirectory(in: applicationSupport)
        guard fileManager.fileExists(atPath: old.path) else { return nil }

        renameLegacyLog(in: old.appendingPathComponent("Logs"),
                        unlessIn: new.appendingPathComponent("Logs"), fileManager: fileManager)
        let moved = merge(old, into: new, fileManager: fileManager)
        removeIfEmpty(old, fileManager: fileManager)
        return moved > 0 ? old : nil
    }

    /// Move each item of `source` into `destination`. Folders present in both are
    /// merged; a file present in both keeps Spindle's copy, and the old one is
    /// moved in as "name (AutoRip2MKV).ext". Returns items moved.
    private static func merge(_ source: URL, into destination: URL, fileManager: FileManager) -> Int {
        var isDirectory: ObjCBool = false
        if !fileManager.fileExists(atPath: destination.path, isDirectory: &isDirectory) {
            do {
                try fileManager.moveItem(at: source, to: destination)
                return 1
            } catch {
                NSLog("Spindle: couldn't move \(source.path): \(error.localizedDescription)")
                return 0
            }
        }
        guard isDirectory.boolValue else {
            let kept = destination.deletingPathExtension().lastPathComponent + " (AutoRip2MKV)"
            var renamed = destination.deletingLastPathComponent().appendingPathComponent(kept)
            if !destination.pathExtension.isEmpty { renamed.appendPathExtension(destination.pathExtension) }
            guard !fileManager.fileExists(atPath: renamed.path) else { return 0 }
            return (try? fileManager.moveItem(at: source, to: renamed)) != nil ? 1 : 0
        }
        guard let items = try? fileManager.contentsOfDirectory(atPath: source.path) else { return 0 }
        var moved = 0
        for item in items {
            let from = source.appendingPathComponent(item)
            moved += merge(from, into: destination.appendingPathComponent(item), fileManager: fileManager)
            removeIfEmpty(from, fileManager: fileManager)
        }
        return moved
    }

    private static func removeIfEmpty(_ url: URL, fileManager: FileManager) {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue,
              let items = try? fileManager.contentsOfDirectory(atPath: url.path),
              items.allSatisfy({ $0 == ".DS_Store" }) else { return }
        try? fileManager.removeItem(at: url)
    }

    /// Rename the old main log to Spindle.log, so the log carries on, unless
    /// Spindle has already started its own.
    private static func renameLegacyLog(in logs: URL, unlessIn newLogs: URL, fileManager: FileManager) {
        let old = logs.appendingPathComponent("AutoRip2MKV.log")
        let new = logs.appendingPathComponent("\(name).log")
        let spindles = newLogs.appendingPathComponent("\(name).log")
        if fileManager.fileExists(atPath: old.path), !fileManager.fileExists(atPath: new.path),
           !fileManager.fileExists(atPath: spindles.path) {
            try? fileManager.moveItem(at: old, to: new)
        }
    }
}
