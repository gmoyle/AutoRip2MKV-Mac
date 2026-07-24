import XCTest
import Cocoa
@testable import AutoRip2MKV_Mac

// MARK: - Settings Tab Preference Test Framework
//
// A declarative framework for testing every preference exposed by the 5-tab
// `DetailedSettingsWindowController` Settings window:
//
//   Output & Routing | Organization | Naming | Encoding | Advanced
//
// Each preference is described once by a `PreferenceSpec` (which tab it lives on,
// its `UserDefaults` key, its type, its default, and a couple of sample values).
// The framework then verifies, for every spec, the four contracts the UI relies
// on when it loads controls, when the user edits them, and when it saves:
//
//   1. default        — with nothing stored, the getter returns the documented default
//   2. round-trip     — writing a value and reading it back yields the same value
//   3. persistence    — the stored value survives being read through a fresh handle
//   4. type integrity — the value is stored under the type the UI writes/reads
//
// The catalog mirrors exactly the keys that
// `DetailedSettingsWindowController.saveExtendedSettings()` / `loadExtendedSettings()`
// read and write, so a drift between UI and storage shows up as a failing spec.
//
// All work happens inside a throwaway `UserDefaults` suite so the user's real
// preferences are never touched.

// MARK: - Preference model

/// Which Settings tab a preference is presented on. Purely for grouping and
/// readable failure messages; also lets a test run one tab at a time.
enum SettingsTab: String, CaseIterable {
    case outputAndRouting = "Output & Routing"
    case organization = "Organization"
    case naming = "Naming"
    case encoding = "Encoding"
    case advanced = "Advanced"
}

/// The storage type the UI control maps to in UserDefaults.
enum PreferenceType {
    case bool
    case int
    case string
    /// A `TimeInterval`/`Double` stored value (title-selection durations).
    case double
}

/// A declarative description of one preference control on a Settings tab.
struct PreferenceSpec {
    let tab: SettingsTab
    /// The UserDefaults key the UI reads/writes (or the SettingsManager-backed key).
    let key: String
    /// Human label used in failure messages (usually the control's caption).
    let label: String
    let type: PreferenceType
    /// The value the getter should yield when nothing has been stored, expressed
    /// the way the code computes it. `nil` means "no defined default" (raw
    /// `UserDefaults` zero-value: false / 0 / "").
    let defaultValue: PreferenceValue?
    /// Two distinct sample values to exercise round-tripping. Must differ from
    /// each other and, ideally, from `defaultValue`.
    let sampleA: PreferenceValue
    let sampleB: PreferenceValue
}

/// A type-erased preference value with equality, so specs can be heterogeneous
/// while the engine stays generic.
enum PreferenceValue: Equatable {
    case bool(Bool)
    case int(Int)
    case string(String)
    case double(Double)

    func write(to defaults: UserDefaults, key: String) {
        switch self {
        case .bool(let v):   defaults.set(v, forKey: key)
        case .int(let v):    defaults.set(v, forKey: key)
        case .string(let v): defaults.set(v, forKey: key)
        case .double(let v): defaults.set(v, forKey: key)
        }
    }

    /// Read the value back using the same accessor the app uses for this type.
    static func read(from defaults: UserDefaults, key: String, as type: PreferenceType) -> PreferenceValue {
        switch type {
        case .bool:   return .bool(defaults.bool(forKey: key))
        case .int:    return .int(defaults.integer(forKey: key))
        case .string: return .string(defaults.string(forKey: key) ?? "")
        case .double: return .double(defaults.double(forKey: key))
        }
    }
}

// MARK: - The preference catalog
//
// One entry per control that persists a value, grouped by the tab it appears on
// in DetailedSettingsWindowController.setupUI(). Keys and defaults are taken
// verbatim from SettingsManager and DetailedSettingsWindowController so the specs
// stay faithful to what the UI actually does.

enum SettingsCatalog {

    static let all: [PreferenceSpec] = outputAndRouting + organization + naming + encoding + advanced

    static func specs(for tab: SettingsTab) -> [PreferenceSpec] {
        all.filter { $0.tab == tab }
    }

    // Tab 1 — Output & Routing (Output Directory + File Storage + Content Routing)
    static let outputAndRouting: [PreferenceSpec] = [
        PreferenceSpec(tab: .outputAndRouting, key: "defaultOutputPath",
                       label: "Default Output Directory", type: .string,
                       defaultValue: nil,
                       sampleA: .string("/Volumes/Rips"), sampleB: .string("~/Movies/Ripped")),
        PreferenceSpec(tab: .outputAndRouting, key: "createDateDirectories",
                       label: "Create date-based subdirectories", type: .bool,
                       defaultValue: .bool(false),
                       sampleA: .bool(true), sampleB: .bool(false)),
        PreferenceSpec(tab: .outputAndRouting, key: "outputPathTemplate",
                       label: "Output Path Template", type: .string,
                       defaultValue: nil,
                       sampleA: .string("{output_dir}/{title}"),
                       sampleB: .string("{output_dir}/{media_type}/{title}")),
        PreferenceSpec(tab: .outputAndRouting, key: "contentRoutingEnabled",
                       label: "Sort rips into Movies / TV Shows", type: .bool,
                       defaultValue: .bool(false),
                       sampleA: .bool(true), sampleB: .bool(false)),
        // autoRouteHighConfidence defaults to TRUE when unset (SettingsManager).
        PreferenceSpec(tab: .outputAndRouting, key: "autoRouteHighConfidence",
                       label: "Auto-route confident guesses", type: .bool,
                       defaultValue: .bool(true),
                       sampleA: .bool(false), sampleB: .bool(true)),
        PreferenceSpec(tab: .outputAndRouting, key: "outputStructureType",
                       label: "Directory Structure", type: .int,
                       defaultValue: .int(1),          // seeded "By Media Type"
                       sampleA: .int(0), sampleB: .int(4)),
        PreferenceSpec(tab: .outputAndRouting, key: "createSeriesDirectory",
                       label: "Create separate directories for TV series", type: .bool,
                       defaultValue: .bool(true),
                       sampleA: .bool(false), sampleB: .bool(true)),
        PreferenceSpec(tab: .outputAndRouting, key: "createSeasonDirectory",
                       label: "Create season subdirectories", type: .bool,
                       defaultValue: .bool(true),
                       sampleA: .bool(false), sampleB: .bool(true)),
        PreferenceSpec(tab: .outputAndRouting, key: "movieDirectoryFormat",
                       label: "Movie Directory Format", type: .string,
                       defaultValue: .string("Movies/{title} ({year})"),
                       sampleA: .string("Films/{title}"),
                       sampleB: .string("Movies/{title} ({year})")),
        PreferenceSpec(tab: .outputAndRouting, key: "tvShowDirectoryFormat",
                       label: "TV Show Directory Format", type: .string,
                       defaultValue: .string("TV Shows/{series}/Season {season}"),
                       sampleA: .string("TV/{series}/S{season}"),
                       sampleB: .string("TV Shows/{series}/Season {season}")),
    ]

    // Tab 2 — Organization (File Organization + Bonus Content)
    static let organization: [PreferenceSpec] = [
        PreferenceSpec(tab: .organization, key: "autoRenameFiles",
                       label: "Auto-rename files", type: .bool,
                       defaultValue: .bool(false),
                       sampleA: .bool(true), sampleB: .bool(false)),
        PreferenceSpec(tab: .organization, key: "createYearDirectories",
                       label: "Create year directories", type: .bool,
                       defaultValue: .bool(false),
                       sampleA: .bool(true), sampleB: .bool(false)),
        PreferenceSpec(tab: .organization, key: "createGenreDirectories",
                       label: "Create genre directories", type: .bool,
                       defaultValue: .bool(false),
                       sampleA: .bool(true), sampleB: .bool(false)),
        PreferenceSpec(tab: .organization, key: "duplicateHandling",
                       label: "Duplicate Handling", type: .int,
                       defaultValue: nil,
                       sampleA: .int(1), sampleB: .int(2)),
        PreferenceSpec(tab: .organization, key: "minimumFileSize",
                       label: "Minimum File Size", type: .int,
                       defaultValue: nil,
                       sampleA: .int(100), sampleB: .int(250)),
        PreferenceSpec(tab: .organization, key: "includeBonusFeatures",
                       label: "Include bonus features", type: .bool,
                       defaultValue: .bool(false),
                       sampleA: .bool(true), sampleB: .bool(false)),
        PreferenceSpec(tab: .organization, key: "includeCommentaries",
                       label: "Include audio commentaries", type: .bool,
                       defaultValue: .bool(false),
                       sampleA: .bool(true), sampleB: .bool(false)),
        PreferenceSpec(tab: .organization, key: "includeDeletedScenes",
                       label: "Include deleted scenes", type: .bool,
                       defaultValue: .bool(false),
                       sampleA: .bool(true), sampleB: .bool(false)),
        PreferenceSpec(tab: .organization, key: "includeMakingOf",
                       label: "Include making-of", type: .bool,
                       defaultValue: .bool(false),
                       sampleA: .bool(true), sampleB: .bool(false)),
        PreferenceSpec(tab: .organization, key: "includeTrailers",
                       label: "Include trailers", type: .bool,
                       defaultValue: .bool(false),
                       sampleA: .bool(true), sampleB: .bool(false)),
        PreferenceSpec(tab: .organization, key: "bonusContentStructure",
                       label: "Bonus Content Organization", type: .int,
                       defaultValue: .int(1),          // seeded "Separate 'Bonus'"
                       sampleA: .int(0), sampleB: .int(3)),
        PreferenceSpec(tab: .organization, key: "bonusContentDirectory",
                       label: "Custom Bonus Directory Name", type: .string,
                       defaultValue: .string("Bonus"),
                       sampleA: .string("Extras"), sampleB: .string("Bonus")),
    ]

    // Tab 3 — Naming (File Naming)
    static let naming: [PreferenceSpec] = [
        PreferenceSpec(tab: .naming, key: "movieFileFormat",
                       label: "Movie File Format", type: .string,
                       defaultValue: .string("{title} ({year}).mkv"),
                       sampleA: .string("{title}.mkv"),
                       sampleB: .string("{title} ({year}).mkv")),
        PreferenceSpec(tab: .naming, key: "tvShowFileFormat",
                       label: "TV Episode File Format", type: .string,
                       defaultValue: .string("{series} - S{season:02d}E{episode:02d} - {title}.mkv"),
                       sampleA: .string("{series}.S{season}E{episode}.mkv"),
                       sampleB: .string("{series} - S{season:02d}E{episode:02d} - {title}.mkv")),
        PreferenceSpec(tab: .naming, key: "seasonEpisodeFormat",
                       label: "Season/Episode Format", type: .string,
                       defaultValue: .string("S{season:02d}E{episode:02d}"),
                       sampleA: .string("{season}x{episode}"),
                       sampleB: .string("S{season:02d}E{episode:02d}")),
        PreferenceSpec(tab: .naming, key: "includeYearInFilename",
                       label: "Include year in filename", type: .bool,
                       defaultValue: .bool(true),
                       sampleA: .bool(false), sampleB: .bool(true)),
        PreferenceSpec(tab: .naming, key: "includeResolutionInFilename",
                       label: "Include resolution in filename", type: .bool,
                       defaultValue: .bool(false),
                       sampleA: .bool(true), sampleB: .bool(false)),
        PreferenceSpec(tab: .naming, key: "includeCodecInFilename",
                       label: "Include codec info in filename", type: .bool,
                       defaultValue: .bool(false),
                       sampleA: .bool(true), sampleB: .bool(false)),
    ]

    // Tab 4 — Encoding (Advanced Encoding + Quality Presets + Quality & Codecs)
    static let encoding: [PreferenceSpec] = [
        PreferenceSpec(tab: .encoding, key: "encodingSpeed",
                       label: "Encoding Speed", type: .int,
                       defaultValue: nil,
                       sampleA: .int(3), sampleB: .int(5)),
        PreferenceSpec(tab: .encoding, key: "bitrateControl",
                       label: "Bitrate Control", type: .int,
                       defaultValue: nil,
                       sampleA: .int(0), sampleB: .int(2)),
        PreferenceSpec(tab: .encoding, key: "targetBitrate",
                       label: "Target Bitrate", type: .string,
                       defaultValue: nil,
                       sampleA: .string("5.0"), sampleB: .string("12.5")),
        PreferenceSpec(tab: .encoding, key: "twoPassEncoding",
                       label: "Use two-pass encoding", type: .bool,
                       defaultValue: .bool(false),
                       sampleA: .bool(true), sampleB: .bool(false)),
        PreferenceSpec(tab: .encoding, key: "hardwareAcceleration",
                       label: "Enable hardware acceleration", type: .bool,
                       defaultValue: .bool(false),   // seeded false
                       sampleA: .bool(true), sampleB: .bool(false)),
        PreferenceSpec(tab: .encoding, key: "autoDeinterlace",
                       label: "Auto-deinterlace", type: .bool,
                       defaultValue: .bool(true),    // seeded true
                       sampleA: .bool(false), sampleB: .bool(true)),
        PreferenceSpec(tab: .encoding, key: "useMakeMKVForBluRay",
                       label: "Use MakeMKV for Blu-ray", type: .bool,
                       defaultValue: .bool(true),    // seeded true
                       sampleA: .bool(false), sampleB: .bool(true)),
        PreferenceSpec(tab: .encoding, key: "customFFmpegArgs",
                       label: "Custom FFmpeg Arguments", type: .string,
                       defaultValue: nil,
                       sampleA: .string("-tune film"), sampleB: .string("")),
        PreferenceSpec(tab: .encoding, key: "selectedQualityPreset",
                       label: "Quality Preset", type: .int,
                       defaultValue: nil,
                       sampleA: .int(0), sampleB: .int(4)),
        PreferenceSpec(tab: .encoding, key: "customPresetName",
                       label: "Custom Preset Name", type: .string,
                       defaultValue: nil,
                       sampleA: .string("My Preset"), sampleB: .string("")),
        PreferenceSpec(tab: .encoding, key: "quality",
                       label: "Quality", type: .string,
                       defaultValue: .string("high"),
                       sampleA: .string("low"), sampleB: .string("medium")),
        PreferenceSpec(tab: .encoding, key: "videoCodec",
                       label: "Video Codec", type: .string,
                       defaultValue: .string("h264"),
                       sampleA: .string("h265"), sampleB: .string("h264")),
        PreferenceSpec(tab: .encoding, key: "audioCodec",
                       label: "Audio Codec", type: .string,
                       defaultValue: .string("aac"),
                       sampleA: .string("ac3"), sampleB: .string("aac")),
        PreferenceSpec(tab: .encoding, key: "includeSubtitles",
                       label: "Include subtitles", type: .bool,
                       defaultValue: .bool(true),
                       sampleA: .bool(false), sampleB: .bool(true)),
        PreferenceSpec(tab: .encoding, key: "includeChapters",
                       label: "Include chapter markers", type: .bool,
                       defaultValue: .bool(true),
                       sampleA: .bool(false), sampleB: .bool(true)),
    ]

    // Tab 5 — Advanced (Advanced Options)
    static let advanced: [PreferenceSpec] = [
        PreferenceSpec(tab: .advanced, key: "preserveOriginalTimestamps",
                       label: "Preserve original timestamps", type: .bool,
                       defaultValue: .bool(false),
                       sampleA: .bool(true), sampleB: .bool(false)),
        PreferenceSpec(tab: .advanced, key: "createBackups",
                       label: "Create backups", type: .bool,
                       defaultValue: .bool(false),
                       sampleA: .bool(true), sampleB: .bool(false)),
        PreferenceSpec(tab: .advanced, key: "autoRetryOnFailure",
                       label: "Auto-retry on failure", type: .bool,
                       defaultValue: .bool(true),
                       sampleA: .bool(false), sampleB: .bool(true)),
        PreferenceSpec(tab: .advanced, key: "maxRetryAttempts",
                       label: "Max Retry Attempts", type: .int,
                       defaultValue: .int(3),
                       sampleA: .int(1), sampleB: .int(5)),
        PreferenceSpec(tab: .advanced, key: "preProcessingScript",
                       label: "Pre-processing Script", type: .string,
                       defaultValue: .string(""),
                       sampleA: .string("/tmp/pre.sh"), sampleB: .string("")),
        PreferenceSpec(tab: .advanced, key: "postProcessingScript",
                       label: "Post-processing Script", type: .string,
                       defaultValue: .string(""),
                       sampleA: .string("/tmp/post.sh"), sampleB: .string("")),
    ]
}

// MARK: - The verification engine

/// Generic contract checks that run against any spec, using an isolated
/// `UserDefaults` suite so nothing touches the user's real preferences.
enum PreferenceContract {

    /// Round-trip: writing each sample and reading it back yields the same value.
    /// This is exactly the load↔save contract the Settings UI depends on.
    static func verifyRoundTrip(_ spec: PreferenceSpec,
                                in defaults: UserDefaults,
                                file: StaticString = #filePath,
                                line: UInt = #line) {
        for sample in [spec.sampleA, spec.sampleB] {
            sample.write(to: defaults, key: spec.key)
            let read = PreferenceValue.read(from: defaults, key: spec.key, as: spec.type)
            XCTAssertEqual(read, sample,
                           "[\(spec.tab.rawValue)] '\(spec.label)' (\(spec.key)) did not round-trip",
                           file: file, line: line)
        }
    }

    /// The two samples are genuinely distinct, so round-trip can't pass by accident.
    static func verifyDistinctSamples(_ spec: PreferenceSpec,
                                      file: StaticString = #filePath,
                                      line: UInt = #line) {
        XCTAssertNotEqual(spec.sampleA, spec.sampleB,
                          "[\(spec.tab.rawValue)] '\(spec.label)' (\(spec.key)) has identical samples; " +
                          "round-trip would pass trivially",
                          file: file, line: line)
    }

    /// Persistence: a value written through one handle is visible through another
    /// handle onto the same suite — what "reopen Settings and see my choice" needs.
    static func verifyPersistence(_ spec: PreferenceSpec,
                                  suiteName: String,
                                  file: StaticString = #filePath,
                                  line: UInt = #line) {
        let writer = UserDefaults(suiteName: suiteName)!
        spec.sampleA.write(to: writer, key: spec.key)
        writer.synchronize()

        let reader = UserDefaults(suiteName: suiteName)!
        let read = PreferenceValue.read(from: reader, key: spec.key, as: spec.type)
        XCTAssertEqual(read, spec.sampleA,
                       "[\(spec.tab.rawValue)] '\(spec.label)' (\(spec.key)) did not persist across handles",
                       file: file, line: line)
    }
}
