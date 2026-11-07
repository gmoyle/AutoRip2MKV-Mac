import XCTest
@testable import Spindle

/// Spindle was AutoRip2MKV; first launch carries settings and app data over.
final class AppIdentityMigrationTests: XCTestCase {

    private var root: URL!
    private var defaults: UserDefaults!
    private let suite = "SpindleMigrationTests"

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("spindle-migration-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suite)
        try? FileManager.default.removeItem(at: root)
    }

    func testCopiesOldSettingsWithoutOverwritingNewOnes() {
        defaults.set(false, forKey: "autoEjectEnabled")
        let copied = AppIdentity.copyLegacySettings(
            ["autoEjectEnabled": true, "moviesRootDirectory": "/Volumes/Media/Movies"], into: defaults)
        XCTAssertEqual(copied, 1)
        XCTAssertEqual(defaults.string(forKey: "moviesRootDirectory"), "/Volumes/Media/Movies")
        XCTAssertFalse(defaults.bool(forKey: "autoEjectEnabled"), "a value already set in Spindle wins")
    }

    func testMovesOldSupportFolderAndRenamesLog() throws {
        let old = root.appendingPathComponent("AutoRip2MKV-Mac/Logs", isDirectory: true)
        try FileManager.default.createDirectory(at: old, withIntermediateDirectories: true)
        try Data("history".utf8).write(to: root.appendingPathComponent("AutoRip2MKV-Mac/rip_history.json"))
        try Data("log".utf8).write(to: old.appendingPathComponent("AutoRip2MKV.log"))

        XCTAssertNotNil(AppIdentity.moveLegacySupportDirectory(in: root))

        let new = root.appendingPathComponent("Spindle")
        XCTAssertTrue(FileManager.default.fileExists(atPath: new.appendingPathComponent("rip_history.json").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: new.appendingPathComponent("Logs/Spindle.log").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("AutoRip2MKV-Mac").path))
    }

    func testMergesIntoASpindleFolderThatAlreadyHasLogs() throws {
        // A test run or an earlier launch created Spindle/Logs before the move ran.
        let fm = FileManager.default
        let old = root.appendingPathComponent("AutoRip2MKV-Mac")
        let new = root.appendingPathComponent("Spindle")
        try fm.createDirectory(at: old.appendingPathComponent("Logs"), withIntermediateDirectories: true)
        try fm.createDirectory(at: new.appendingPathComponent("Logs"), withIntermediateDirectories: true)
        try Data("history".utf8).write(to: old.appendingPathComponent("rip_history.json"))
        try Data("ffmpeg".utf8).write(to: old.appendingPathComponent("ffmpeg"))
        try Data("old errors".utf8).write(to: old.appendingPathComponent("Logs/Errors.log"))
        try Data("old log".utf8).write(to: old.appendingPathComponent("Logs/AutoRip2MKV.log"))
        try Data("new errors".utf8).write(to: new.appendingPathComponent("Logs/Errors.log"))
        try Data("new log".utf8).write(to: new.appendingPathComponent("Logs/Spindle.log"))

        XCTAssertNotNil(AppIdentity.moveLegacySupportDirectory(in: root))

        func text(_ path: String) -> String? {
            try? String(contentsOf: new.appendingPathComponent(path), encoding: .utf8)
        }
        XCTAssertEqual(text("rip_history.json"), "history")
        XCTAssertEqual(text("ffmpeg"), "ffmpeg")
        XCTAssertEqual(text("Logs/Errors.log"), "new errors", "Spindle's own file is never overwritten")
        XCTAssertEqual(text("Logs/Errors (AutoRip2MKV).log"), "old errors")
        XCTAssertEqual(text("Logs/Spindle.log"), "new log")
        XCTAssertEqual(text("Logs/AutoRip2MKV.log"), "old log")
        XCTAssertFalse(fm.fileExists(atPath: old.path), "the old folder is removed once emptied")
    }

    func testNothingToMoveOnAFreshInstall() {
        XCTAssertNil(AppIdentity.moveLegacySupportDirectory(in: root))
    }
}
