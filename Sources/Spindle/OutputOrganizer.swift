import Foundation

/// Decides the on-disk folder a finished rip is written into, honoring the user's
/// "Directory Structure" setting (Output & Routing tab). This is the single choke
/// point the DVD / Blu-ray / HD DVD rippers route through, replacing the three
/// duplicated `if plexName … else createOrganizedOutputDirectory` blocks.
///
/// Only structure choices we can actually feed are supported end-to-end: the rip
/// pipeline knows a disc title (optionally "Title (Year)") and its media type, so
/// `{title}`, `{year}`, and the media-type split resolve. Season/episode/genre are
/// not known at rip time, so By-Genre falls back to an "Unknown" bucket and the
/// custom template leaves unknown tokens empty rather than emitting "(0)"/"Season 1".
enum OutputOrganizer {

    /// A rip's known identity, parsed from the resolved Plex title or disc label.
    struct RipInfo {
        /// Clean title without a trailing year, e.g. "Hangmen".
        let title: String
        /// Release year if the resolved title carried one ("Hangmen (2017)"), else nil.
        let year: Int?
        /// Whether content routing classified this as a movie / TV show / unknown.
        let contentType: ContentType

        /// "Title (Year)" when a year is known, else just the title. This matches the
        /// existing Plex folder/file naming so behavior is unchanged for the default
        /// (By Media Type) structure.
        var plexName: String {
            if let year = year { return "\(title) (\(year))" }
            return title
        }
    }

    /// Parse a resolved display name (e.g. "Hangmen (2017)") into title + year.
    /// Falls back to the whole string as the title when there's no trailing "(YYYY)".
    static func parse(displayName: String, contentType: ContentType) -> RipInfo {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        // Match a trailing " (YYYY)" with a plausible film year.
        if let range = trimmed.range(of: #"\s*\((19|20)\d{2}\)$"#, options: .regularExpression) {
            let yearString = trimmed[range].filter { $0.isNumber }
            let title = String(trimmed[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            return RipInfo(title: title.isEmpty ? trimmed : title,
                           year: Int(yearString), contentType: contentType)
        }
        return RipInfo(title: trimmed, year: nil, contentType: contentType)
    }

    /// The organized output directory for a rip, based on the user's structure
    /// setting. Creates the directory (with intermediates); returns `baseDirectory`
    /// unchanged if creation fails, so a rip is never lost to a bad template.
    ///
    /// - Parameters:
    ///   - baseDirectory: the user's chosen output root.
    ///   - info: the rip's parsed identity.
    ///   - mediaTypeFolderName: fallback folder for the media type (e.g. "Blu-ray")
    ///     used when there's no content-routing signal, preserving legacy layout.
    ///   - settings: the settings source (injectable for tests).
    static func directory(baseDirectory: String,
                          info: RipInfo,
                          mediaTypeFolderName: String,
                          settings: SettingsManager = .shared,
                          fileManager: FileManager = .default) -> String {
        let path = plannedDirectory(baseDirectory: baseDirectory, info: info,
                                    mediaTypeFolderName: mediaTypeFolderName, settings: settings)
        do {
            try fileManager.createDirectory(atPath: path, withIntermediateDirectories: true)
            return path
        } catch {
            return baseDirectory
        }
    }

    /// Pure path computation (no filesystem side effects), so it can be unit-tested.
    static func plannedDirectory(baseDirectory: String,
                                 info: RipInfo,
                                 mediaTypeFolderName: String,
                                 settings: SettingsManager = .shared) -> String {
        let base = URL(fileURLWithPath: baseDirectory, isDirectory: true)
        let leaf = info.plexName

        switch settings.outputStructureType {
        case 0: // Flat — everything in one folder named for the title.
            return base.appendingPathComponent(leaf).path

        case 2: // By Year — <base>/<year>/<title>. Falls back to media-type folder
                // when the year is unknown, so untitled discs don't pile into one dir.
            if let year = info.year {
                return base.appendingPathComponent(String(year))
                    .appendingPathComponent(leaf).path
            }
            return base.appendingPathComponent(mediaTypeFolderName)
                .appendingPathComponent(leaf).path

        case 3: // By Genre — genre isn't known at rip time, so use an "Unknown" bucket.
            return base.appendingPathComponent("Unknown")
                .appendingPathComponent(leaf).path

        case 4: // Custom — user template, unknown tokens removed rather than faked.
            let relative = applyTemplate(templateFor(info.contentType, settings: settings),
                                         info: info, leaf: leaf)
            return base.appendingPathComponent(relative).path

        default: // 1 == By Media Type (the default). <base>/<TypeOrContent>/<title>.
            let typeFolder = contentFolder(for: info.contentType, fallback: mediaTypeFolderName)
            return base.appendingPathComponent(typeFolder)
                .appendingPathComponent(leaf).path
        }
    }

    // MARK: - Helpers

    /// Folder for the content type when routing classified it, else the media-type
    /// folder (so an unclassified rip keeps the legacy "Blu-ray"/"DVD" layout).
    private static func contentFolder(for type: ContentType, fallback: String) -> String {
        switch type {
        case .movie: return "Movies"
        case .tvShow: return "TV Shows"
        case .unknown: return fallback
        }
    }

    private static func templateFor(_ type: ContentType, settings: SettingsManager) -> String {
        switch type {
        case .movie, .unknown: return settings.movieDirectoryFormat
        case .tvShow: return settings.tvShowDirectoryFormat
        }
    }

    /// Fill a directory template with known tokens; drop segments that depend on
    /// unknown tokens ({season}/{genre}/…) instead of substituting placeholder junk.
    /// Guarantees the rip stays identifiable: if no surviving segment carried the
    /// title/series, the plex `leaf` is appended so the folder is never anonymous.
    private static func applyTemplate(_ template: String, info: RipInfo, leaf: String) -> String {
        let segments = template.split(separator: "/").map(String.init)
        var out: [String] = []
        var titlePresent = false
        for segment in segments {
            let hadTitleToken = segment.contains("{title}") || segment.contains("{series}")
            var s = segment
                .replacingOccurrences(of: "{title}", with: info.title)
                .replacingOccurrences(of: "{series}", with: info.title)
            if let year = info.year {
                s = s.replacingOccurrences(of: "{year}", with: String(year))
            }
            // A segment still referencing an unfilled token has no data — skip it
            // rather than emit "Season {season}" or "({year})" literally.
            if s.contains("{") { continue }
            let cleaned = sanitize(s)
            if !cleaned.isEmpty {
                out.append(cleaned)
                if hadTitleToken { titlePresent = true }
            }
        }
        if !titlePresent {
            let cleanedLeaf = sanitize(leaf)
            if !cleanedLeaf.isEmpty { out.append(cleanedLeaf) }
        }
        return out.isEmpty ? sanitize(leaf) : out.joined(separator: "/")
    }

    /// Strip path-hostile characters and tidy leftover empty parens/whitespace.
    private static func sanitize(_ s: String) -> String {
        let invalid = CharacterSet(charactersIn: "/:*?\"<>|\\")
        return s.components(separatedBy: invalid).joined(separator: "-")
            .replacingOccurrences(of: "()", with: "")
            .trimmingCharacters(in: .whitespaces)
    }
}
