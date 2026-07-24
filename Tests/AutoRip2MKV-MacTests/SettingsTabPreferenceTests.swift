import XCTest
import Cocoa
@testable import AutoRip2MKV_Mac

/// Drives `SettingsTabPreferenceFramework` across every preference on the five
/// Settings tabs. See that file for the model and the contract engine.
///
/// Split into two layers:
///
///   • Storage-contract tests run against an isolated `UserDefaults` suite and
///     use only the framework specs — they never touch the user's real prefs.
///
///   • SettingsManager tests exercise the app's real accessors and its
///     `setDefaultsIfNeeded()` seeding. Those go through `UserDefaults.standard`
///     (SettingsManager isn't injectable), so the suite snapshots and restores
///     every touched key so the developer's real preferences survive the run.
final class SettingsTabPreferenceTests: XCTestCase {

    // MARK: Isolated suite for storage-contract tests

    private var suiteName: String!
    private var suite: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "settings-tab-prefs-\(UUID().uuidString)"
        suite = UserDefaults(suiteName: suiteName)!
    }

    override func tearDown() {
        suite.removePersistentDomain(forName: suiteName)
        suite = nil
        suiteName = nil
        super.tearDown()
    }

    // MARK: - Catalog sanity

    /// The catalog is the source of truth; guard against an empty or malformed one.
    func testCatalogCoversEveryTab() {
        for tab in SettingsTab.allCases {
            XCTAssertFalse(SettingsCatalog.specs(for: tab).isEmpty,
                           "Tab '\(tab.rawValue)' has no preferences in the catalog")
        }
        XCTAssertEqual(SettingsCatalog.all.count,
                       SettingsTab.allCases.reduce(0) { $0 + SettingsCatalog.specs(for: $1).count },
                       "Catalog partition by tab should account for every spec")
    }

    /// No two specs share a key — a duplicate would mean two controls fighting
    /// over one UserDefaults slot.
    func testNoDuplicateKeys() {
        var seen: [String: String] = [:]
        for spec in SettingsCatalog.all {
            if let existing = seen[spec.key] {
                XCTFail("Key '\(spec.key)' used by both '\(existing)' and '\(spec.label)'")
            }
            seen[spec.key] = spec.label
        }
    }

    // MARK: - Generic contracts, all specs

    func testAllSamplesAreDistinct() {
        for spec in SettingsCatalog.all {
            PreferenceContract.verifyDistinctSamples(spec)
        }
    }

    func testAllPreferencesRoundTrip() {
        for spec in SettingsCatalog.all {
            PreferenceContract.verifyRoundTrip(spec, in: suite)
        }
    }

    func testAllPreferencesPersistAcrossHandles() {
        for spec in SettingsCatalog.all {
            PreferenceContract.verifyPersistence(spec, suiteName: suiteName)
        }
    }

    // MARK: - Per-tab round-trip (readable, isolated failures)

    func testOutputAndRoutingTabRoundTrips() { runRoundTrip(for: .outputAndRouting) }
    func testOrganizationTabRoundTrips()      { runRoundTrip(for: .organization) }
    func testNamingTabRoundTrips()            { runRoundTrip(for: .naming) }
    func testEncodingTabRoundTrips()          { runRoundTrip(for: .encoding) }
    func testAdvancedTabRoundTrips()          { runRoundTrip(for: .advanced) }

    private func runRoundTrip(for tab: SettingsTab) {
        let specs = SettingsCatalog.specs(for: tab)
        XCTAssertFalse(specs.isEmpty, "No specs for \(tab.rawValue)")
        for spec in specs {
            PreferenceContract.verifyRoundTrip(spec, in: suite)
        }
    }

    // MARK: - Default-value contract (raw UserDefaults zero-values)
    //
    // For specs that declare a default, verify that reading the key from an EMPTY
    // suite yields that default — but only for defaults the raw accessor itself
    // produces (bool→false, int→0, string→""). Defaults that are actually applied
    // by SettingsManager.setDefaultsIfNeeded() (e.g. autoRoute=true, quality="high")
    // are covered by the SettingsManager tests below, where the seeding runs.

    func testRawZeroValueDefaults() {
        for spec in SettingsCatalog.all {
            guard let def = spec.defaultValue else { continue }
            let isRawZero: Bool
            switch def {
            case .bool(let v):   isRawZero = (v == false)
            case .int(let v):    isRawZero = (v == 0)
            case .string(let v): isRawZero = (v == "")
            case .double(let v): isRawZero = (v == 0)
            }
            guard isRawZero else { continue }
            let read = PreferenceValue.read(from: suite, key: spec.key, as: spec.type)
            XCTAssertEqual(read, def,
                           "[\(spec.tab.rawValue)] '\(spec.label)' (\(spec.key)) empty-store default wrong")
        }
    }
}

// MARK: - SettingsManager real-accessor + seeding tests

/// These exercise the app's actual `SettingsManager` accessors and the
/// `setDefaultsIfNeeded()` seeding that establishes the non-zero defaults the UI
/// shows on first launch. They run against `UserDefaults.standard`, so every key
/// touched is snapshotted and restored to protect the developer's real prefs.
final class SettingsManagerSeedingTests: XCTestCase {

    /// Keys whose seeded default is something other than the raw zero-value, plus
    /// the value setDefaultsIfNeeded()/getters are documented to produce.
    // Note: autoRouteHighConfidence is deliberately NOT here. Its "true" default
    // is a getter-computed fallback (like videoCodec/audioCodec/quality), not a
    // key written by setDefaultsIfNeeded(). It's covered by testGetterDefaults().
    private let seededDefaults: [(key: String, expected: PreferenceValue)] = [
        ("outputStructureType", .int(1)),
        ("createSeriesDirectory", .bool(true)),
        ("createSeasonDirectory", .bool(true)),
        ("movieDirectoryFormat", .string("Movies/{title} ({year})")),
        ("tvShowDirectoryFormat", .string("TV Shows/{series}/Season {season}")),
        ("bonusContentStructure", .int(1)),
        ("bonusContentDirectory", .string("Bonus")),
        ("includeYearInFilename", .bool(true)),
        ("autoDeinterlace", .bool(true)),
        ("useMakeMKVForBluRay", .bool(true)),
        ("includeSubtitles", .bool(true)),
        ("includeChapters", .bool(true)),
        ("intelligentTitleSelection", .bool(true)),
        ("autoRetryOnFailure", .bool(true)),
        ("maxRetryAttempts", .int(3)),
    ]

    /// Every key the seeding or these tests could write; snapshotted for restore.
    private var touchedKeys: [String] { seededDefaults.map { $0.key } + extraKeys }
    private let extraKeys = ["videoCodec", "audioCodec", "quality", "autoRouteHighConfidence"]

    private var snapshot: [String: Any?] = [:]

    override func setUp() {
        super.setUp()
        let d = UserDefaults.standard
        for key in touchedKeys {
            snapshot[key] = d.object(forKey: key)
        }
        // Start from a clean slate so setDefaultsIfNeeded() actually seeds.
        for key in touchedKeys { d.removeObject(forKey: key) }
    }

    override func tearDown() {
        let d = UserDefaults.standard
        for key in touchedKeys {
            if let value = snapshot[key], let value = value {
                d.set(value, forKey: key)
            } else {
                d.removeObject(forKey: key)
            }
        }
        snapshot = [:]
        super.tearDown()
    }

    /// After seeding, every non-zero default matches what the UI shows on first run.
    func testSetDefaultsSeedsExpectedValues() {
        SettingsManager.shared.setDefaultsIfNeeded()
        let d = UserDefaults.standard
        for (key, expected) in seededDefaults {
            // Infer type from the expected value.
            let type: PreferenceType
            switch expected {
            case .bool:   type = .bool
            case .int:    type = .int
            case .string: type = .string
            case .double: type = .double
            }
            let read = PreferenceValue.read(from: d, key: key, as: type)
            XCTAssertEqual(read, expected, "Seeded default for '\(key)' is wrong")
        }
    }

    /// The typed getters return their documented defaults with nothing stored,
    /// independent of seeding (they compute the fallback inline).
    func testGetterDefaults() {
        let m = SettingsManager.shared
        XCTAssertEqual(m.videoCodec, "h264", "videoCodec default")
        XCTAssertEqual(m.audioCodec, "aac", "audioCodec default")
        XCTAssertEqual(m.quality, "high", "quality default")
        XCTAssertTrue(m.autoRouteHighConfidence, "autoRouteHighConfidence default true")
    }

    /// The three SettingsManager string enums round-trip through their accessors,
    /// mirroring the popup→storage mapping the Encoding tab performs on save.
    func testCodecAndQualityAccessorsRoundTrip() {
        let m = SettingsManager.shared
        m.videoCodec = "h265"; XCTAssertEqual(m.videoCodec, "h265")
        m.videoCodec = "h264"; XCTAssertEqual(m.videoCodec, "h264")
        m.audioCodec = "ac3";  XCTAssertEqual(m.audioCodec, "ac3")
        m.audioCodec = "aac";  XCTAssertEqual(m.audioCodec, "aac")
        m.quality = "low";     XCTAssertEqual(m.quality, "low")
        m.quality = "high";    XCTAssertEqual(m.quality, "high")
    }
}
