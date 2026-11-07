import Foundation

/// Downloads the current MakeMKV for Mac from makemkv.com and installs it into
/// /Applications, replacing an expired build. Only ever runs on an explicit
/// click; MakeMKV's own license applies to the installed copy.
final class MakeMKVInstaller {

    enum InstallError: LocalizedError {
        case noDownloadLink
        case downloadFailed(String)
        case mountFailed(String)
        case appNotFoundInImage
        case makemkvRunning
        case installFailed(String)

        var errorDescription: String? {
            switch self {
            case .noDownloadLink: return "Couldn't find the Mac download on makemkv.com."
            case .downloadFailed(let why): return "MakeMKV download failed: \(why)"
            case .mountFailed(let why): return "Couldn't open the MakeMKV disk image: \(why)"
            case .appNotFoundInImage: return "The MakeMKV disk image didn't contain MakeMKV.app."
            case .makemkvRunning: return "MakeMKV is in use (a rip is running). Try again when it's idle."
            case .installFailed(let why): return "Couldn't install MakeMKV: \(why)"
            }
        }
    }

    static let host = "www.makemkv.com"
    static let installPath = "/Applications/MakeMKV.app"

    /// The Mac .dmg link on the download page, e.g.
    /// `/download/makemkv_v2.0.0_osx.dmg` → (URL, "2.0.0"). Only links on
    /// makemkv.com's own /download/ path are accepted. Pure, for tests.
    static func macDownload(fromPageHTML html: String) -> (url: URL, version: String)? {
        let pattern = "/download/makemkv_v([0-9]+(?:\\.[0-9]+)+)_osx\\.dmg"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let pathRange = Range(match.range, in: html),
              let versionRange = Range(match.range(at: 1), in: html),
              let url = URL(string: "https://\(host)\(html[pathRange])") else { return nil }
        return (url, String(html[versionRange]))
    }

    /// Installed MakeMKV version from its Info.plist, if any.
    static func installedVersion(at path: String = installPath) -> String? {
        NSDictionary(contentsOfFile: path + "/Contents/Info.plist")?["CFBundleShortVersionString"] as? String
    }

    private let session: URLSession
    init(session: URLSession = .shared) { self.session = session }

    /// Download and install. `onStatus` and `completion` are called on an
    /// arbitrary queue; completion gets the installed version or an error.
    func install(onStatus: @escaping (String) -> Void,
                 completion: @escaping (Result<String, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                completion(.success(try self.installSync(onStatus: onStatus)))
            } catch {
                Logger.shared.logError(error, context: "MakeMKV install failed")
                completion(.failure(error))
            }
        }
    }

    private func installSync(onStatus: (String) -> Void) throws -> String {
        if Self.isMakeMKVRunning() { throw InstallError.makemkvRunning }

        onStatus("Finding the latest MakeMKV...")
        let page = try fetch(MakeMKVBackend.downloadURL)
        guard let html = String(data: page, encoding: .utf8) ?? String(data: page, encoding: .isoLatin1),
              let (dmgURL, version) = Self.macDownload(fromPageHTML: html) else {
            throw InstallError.noDownloadLink
        }

        onStatus("Downloading MakeMKV \(version)...")
        let work = FileManager.default.temporaryDirectory
            .appendingPathComponent("makemkv-install-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: work) }
        let dmg = work.appendingPathComponent(dmgURL.lastPathComponent)
        try download(dmgURL, to: dmg)

        onStatus("Installing MakeMKV \(version)...")
        let mount = work.appendingPathComponent("mnt").path
        try attach(dmg.path, at: mount)
        defer { _ = Self.run("/usr/bin/hdiutil", ["detach", mount, "-force"]) }

        let apps = (try? FileManager.default.contentsOfDirectory(atPath: mount))?
            .filter { $0.hasSuffix(".app") && $0.lowercased().contains("makemkv") } ?? []
        guard let appName = apps.first else { throw InstallError.appNotFoundInImage }

        if Self.isMakeMKVRunning() { throw InstallError.makemkvRunning }
        // Copy beside the old app, then swap, so a failed copy leaves the old one.
        let staged = Self.installPath + ".installing"
        try? FileManager.default.removeItem(atPath: staged)
        let copy = Self.run("/usr/bin/ditto", ["\(mount)/\(appName)", staged])
        guard copy.status == 0 else {
            try? FileManager.default.removeItem(atPath: staged)
            throw InstallError.installFailed(copy.output)
        }
        do {
            if FileManager.default.fileExists(atPath: Self.installPath) {
                _ = try FileManager.default.replaceItemAt(URL(fileURLWithPath: Self.installPath),
                                                          withItemAt: URL(fileURLWithPath: staged))
            } else {
                try FileManager.default.moveItem(atPath: staged, toPath: Self.installPath)
            }
        } catch {
            try? FileManager.default.removeItem(atPath: staged)
            throw InstallError.installFailed(error.localizedDescription)
        }
        let installed = Self.installedVersion() ?? version
        Logger.shared.log("Installed MakeMKV \(installed) from \(dmgURL.absoluteString)",
                          level: .info, category: .general)
        return installed
    }

    // MARK: - Helpers

    private func fetch(_ url: URL) throws -> Data {
        var result: Result<Data, Error> = .failure(InstallError.downloadFailed("no response"))
        let done = DispatchSemaphore(value: 0)
        session.dataTask(with: url) { data, response, error in
            if let error = error {
                result = .failure(InstallError.downloadFailed(error.localizedDescription))
            } else if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                result = .failure(InstallError.downloadFailed("HTTP \(http.statusCode)"))
            } else {
                result = .success(data ?? Data())
            }
            done.signal()
        }.resume()
        done.wait()
        return try result.get()
    }

    private func download(_ url: URL, to destination: URL) throws {
        var failure: Error?
        let done = DispatchSemaphore(value: 0)
        session.downloadTask(with: url) { location, response, error in
            defer { done.signal() }
            if let error = error { failure = InstallError.downloadFailed(error.localizedDescription); return }
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                failure = InstallError.downloadFailed("HTTP \(http.statusCode)"); return
            }
            // Redirects must stay on makemkv.com.
            guard response?.url?.host == Self.host, let location = location else {
                failure = InstallError.downloadFailed("unexpected download location"); return
            }
            do { try FileManager.default.moveItem(at: location, to: destination) } catch { failure = error }
        }.resume()
        done.wait()
        if let failure = failure { throw failure }
    }

    /// Mount read-only and hidden. MakeMKV's image may carry a license
    /// agreement; the user agreed to install it, so answer hdiutil's prompt.
    private func attach(_ dmg: String, at mount: String) throws {
        try FileManager.default.createDirectory(atPath: mount, withIntermediateDirectories: true)
        let result = Self.run("/usr/bin/hdiutil",
                              ["attach", dmg, "-nobrowse", "-readonly", "-noautoopen", "-mountpoint", mount],
                              stdin: "Y\n")
        guard result.status == 0 else { throw InstallError.mountFailed(result.output) }
    }

    static func isMakeMKVRunning() -> Bool {
        run("/usr/bin/pgrep", ["-x", "makemkvcon"]).status == 0
            || run("/usr/bin/pgrep", ["-x", "makemkv"]).status == 0
    }

    @discardableResult
    static func run(_ exe: String, _ args: [String], stdin: String? = nil) -> (status: Int32, output: String) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: exe)
        task.arguments = args
        let out = Pipe()
        task.standardOutput = out
        task.standardError = out
        let input = Pipe()
        task.standardInput = stdin == nil ? FileHandle.nullDevice : input
        do { try task.run() } catch { return (-1, error.localizedDescription) }
        if let stdin = stdin {
            input.fileHandleForWriting.write(Data(stdin.utf8))
            try? input.fileHandleForWriting.close()
        }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        return (task.terminationStatus, String(data: data, encoding: .utf8) ?? "")
    }
}
