import XCTest
@testable import AutoRip2MKV_Mac

/// Tests for the central rip registry and disc-identity fingerprinting — the
/// location-independent "have I ripped this disc?" mechanism that replaces the
/// fragile per-folder rip_complete.json marker.
final class RipHistoryTests: XCTestCase {

    private func makeStore() -> RipHistoryStore {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("rip-history-\(UUID().uuidString).json")
        return RipHistoryStore(fileURL: url)
    }

    private func entry(identity: String, fingerprint: [String: String],
                       location: String = "/tmp/out") -> RipHistoryEntry {
        RipHistoryEntry(discIdentity: identity, volumeName: "DISC",
                        title: "Some Title", settingsFingerprint: fingerprint,
                        outputLocation: location, completedAt: Date())
    }

    // MARK: - Store

    func testRecordAndLookup() {
        let store = makeStore()
        let fp = ["quality": "high"]
        store.record(entry(identity: "DISC#abc", fingerprint: fp))
        XCTAssertTrue(store.isAlreadyRipped(identity: "DISC#abc", settingsFingerprint: fp))
    }

    func testUnknownDiscIsNotRipped() {
        let store = makeStore()
        XCTAssertFalse(store.isAlreadyRipped(identity: "NOPE#zzz", settingsFingerprint: [:]))
    }

    func testSettingsChangeReportsNotRipped() {
        let store = makeStore()
        store.record(entry(identity: "DISC#abc", fingerprint: ["quality": "high"]))
        // Same disc, different settings → should re-rip.
        XCTAssertFalse(store.isAlreadyRipped(
            identity: "DISC#abc", settingsFingerprint: ["quality": "low"]))
    }

    func testPersistsAcrossInstances() {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("rip-history-persist-\(UUID().uuidString).json")
        let fp = ["v": "1"]
        RipHistoryStore(fileURL: url).record(entry(identity: "D#1", fingerprint: fp))
        XCTAssertTrue(RipHistoryStore(fileURL: url)
            .isAlreadyRipped(identity: "D#1", settingsFingerprint: fp))
    }

    func testUpdateOutputLocation() {
        let store = makeStore()
        store.record(entry(identity: "D#1", fingerprint: [:], location: "/old"))
        store.updateOutputLocation(identity: "D#1", to: "/new/plex/Movies/Film")
        XCTAssertEqual(store.entry(forIdentity: "D#1")?.outputLocation, "/new/plex/Movies/Film")
    }

    func testRemove() {
        let store = makeStore()
        store.record(entry(identity: "D#1", fingerprint: [:]))
        store.remove(identity: "D#1")
        XCTAssertNil(store.entry(forIdentity: "D#1"))
    }

    func testUpdateOutputLocationFromOldPath() {
        let store = makeStore()
        store.record(entry(identity: "D#1", fingerprint: [:], location: "/staging/Film"))
        store.updateOutputLocation(from: "/staging/Film", to: "/Plex/Movies/Film")
        XCTAssertEqual(store.entry(forIdentity: "D#1")?.outputLocation, "/Plex/Movies/Film")
    }

    // MARK: - Routing records the final location (via ContentRouter's move map)

    func testRouterRecordsFinalLocationAfterMove() throws {
        let base = NSTemporaryDirectory().appending("route-loc-\(UUID().uuidString)")
        let source = (base as NSString).appendingPathComponent("staging/MOVIE_DISC")
        let moviesRoot = (base as NSString).appendingPathComponent("Movies")
        try FileManager.default.createDirectory(atPath: source, withIntermediateDirectories: true)
        FileManager.default.createFile(
            atPath: (source as NSString).appendingPathComponent("film.mkv"), contents: Data("x".utf8))

        let settings = SettingsManager.shared
        let original = settings.moviesRootDirectory
        defer { settings.moviesRootDirectory = original }
        settings.moviesRootDirectory = moviesRoot

        let dest = try ContentRouter.route(folderPath: source, to: .movie, settings: settings)

        // The move should be resolvable by staging path (consumed on read).
        XCTAssertEqual(ContentRouter.finalLocation(forStagingPath: source), dest)
        // ...and consumed, so a second read is nil.
        XCTAssertNil(ContentRouter.finalLocation(forStagingPath: source))
    }

    // MARK: - Disc identity / fingerprint

    private func makeBluRay(streamSizes: [Int]) throws -> String {
        let root = NSTemporaryDirectory().appending("disc-\(UUID().uuidString)")
        let stream = (root as NSString).appendingPathComponent("BDMV/STREAM")
        try FileManager.default.createDirectory(atPath: stream, withIntermediateDirectories: true)
        for (i, s) in streamSizes.enumerated() {
            let p = (stream as NSString).appendingPathComponent(String(format: "%05d.m2ts", i))
            FileManager.default.createFile(atPath: p, contents: Data(count: s))
        }
        return root
    }

    func testIdentityStableForSameDisc() throws {
        let disc = try makeBluRay(streamSizes: [1000, 2000, 3000])
        let a = DiscIdentity.compute(forDiscAt: disc)
        let b = DiscIdentity.compute(forDiscAt: disc)
        XCTAssertEqual(a, b)
        XCTAssertTrue(a.contains("#"), "identity should include a fingerprint")
    }

    func testDifferentDiscsDifferentIdentity() throws {
        let disc1 = try makeBluRay(streamSizes: [1000, 2000, 3000])
        let disc2 = try makeBluRay(streamSizes: [9999, 8888])
        // Same volume label component would still differ by fingerprint; here even
        // the temp folder names differ, so just assert the fingerprints differ.
        XCTAssertNotEqual(DiscIdentity.fingerprint(forDiscAt: disc1),
                          DiscIdentity.fingerprint(forDiscAt: disc2))
    }

    func testFingerprintOrderIndependent() throws {
        // Same set of title sizes in any on-disk order → same fingerprint.
        let disc1 = try makeBluRay(streamSizes: [3000, 1000, 2000])
        let disc2 = try makeBluRay(streamSizes: [1000, 2000, 3000])
        XCTAssertEqual(DiscIdentity.fingerprint(forDiscAt: disc1),
                       DiscIdentity.fingerprint(forDiscAt: disc2))
    }

    func testFingerprintNilForNoStructure() {
        let empty = NSTemporaryDirectory().appending("empty-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(atPath: empty, withIntermediateDirectories: true)
        XCTAssertNil(DiscIdentity.fingerprint(forDiscAt: empty))
        // compute() still returns the label alone.
        XCTAssertFalse(DiscIdentity.compute(forDiscAt: empty).contains("#"))
    }
}
