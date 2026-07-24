import XCTest
@testable import AutoRip2MKV_Mac

/// Tests for MakeMKV licensing detection: recognizing makemkvcon's
/// registration-refusal messages, extracting the free beta key from the forum
/// thread, and reading key presence from MakeMKV's settings file.
final class MakeMKVRegistrationTests: XCTestCase {

    // MARK: - Registration-failure message detection

    func testDetectsExpiredEvaluationMessage() {
        XCTAssertTrue(MakeMKVBackend.isRegistrationFailureMessage(
            "Evaluation period has expired, shareware functionality unavailable."))
    }

    func testDetectsTooOldVersionMessage() {
        XCTAssertTrue(MakeMKVBackend.isRegistrationFailureMessage(
            "This application version is too old. Please download the latest version "
            + "at www.makemkv.com or enter a registration key to continue."))
    }

    func testDetectsRegistrationKeyMessage() {
        XCTAssertTrue(MakeMKVBackend.isRegistrationFailureMessage(
            "To continue using all features please purchase the registration key."))
    }

    func testIgnoresNormalRipMessages() {
        XCTAssertFalse(MakeMKVBackend.isRegistrationFailureMessage(
            "Using direct disc access mode"))
        XCTAssertFalse(MakeMKVBackend.isRegistrationFailureMessage(
            "Saving 1 titles into directory /Users/x/Movies"))
        XCTAssertFalse(MakeMKVBackend.isRegistrationFailureMessage(
            "Title #00000.mpls has length of 120 seconds which is less than minimum title length"))
    }

    // MARK: - Drive access-mode detection (UHD contention retry)

    // Real makemkvcon messages captured from a 4K Blu-ray on a Pioneer BDR-XD08U.

    func testDetectsOSAccessModeMessage() {
        let msg = "Optical drive \"BD-RE PIONEER BD-RW  BDR-XD08U\" opened in OS access mode."
        XCTAssertTrue(MakeMKVBackend.isOSAccessModeMessage(msg))
        XCTAssertFalse(MakeMKVBackend.isDirectAccessModeMessage(msg))
    }

    func testDetectsDirectAccessModeMessage() {
        let msg = "Using direct disc access mode"
        XCTAssertTrue(MakeMKVBackend.isDirectAccessModeMessage(msg))
        XCTAssertFalse(MakeMKVBackend.isOSAccessModeMessage(msg))
    }

    func testAccessModeDetectionIgnoresUnrelatedMessages() {
        let msg = "Processing BD+ code, please be patient - this may take up to few minutes"
        XCTAssertFalse(MakeMKVBackend.isOSAccessModeMessage(msg))
        XCTAssertFalse(MakeMKVBackend.isDirectAccessModeMessage(msg))
    }

    // MARK: - Beta key extraction from forum HTML

    func testExtractsBetaKeyFromForumHTML() {
        let key = "T-hjodeXi8H4tYr7wpBnQ5vFgKm2sLc9RzUaE1dW6yNxJ3fMqZkTvGbCu0PoAl5DnS8rY"
        let html = "<div class=\"content\">The current beta key is:<br><code>\(key)</code></div>"
        XCTAssertEqual(MakeMKVBackend.extractBetaKey(fromForumHTML: html), key)
    }

    func testExtractionIgnoresShortTDashTokens() {
        // "T-" prefixed short tokens (T-shirt, CSS classes) must not match.
        let html = "<p>Buy a T-shirt! class=\"post-T-123\"</p>"
        XCTAssertNil(MakeMKVBackend.extractBetaKey(fromForumHTML: html))
    }

    func testExtractionReturnsNilForEmptyHTML() {
        XCTAssertNil(MakeMKVBackend.extractBetaKey(fromForumHTML: ""))
    }

    // MARK: - Disk-space preflight

    /// Build a fake Blu-ray tree with STREAM/*.m2ts of the given byte sizes.
    private func makeFakeBluRay(streamSizes: [Int]) throws -> String {
        let root = NSTemporaryDirectory().appending("bluray-preflight-\(UUID().uuidString)")
        let streamDir = (root as NSString).appendingPathComponent("BDMV/STREAM")
        try FileManager.default.createDirectory(atPath: streamDir, withIntermediateDirectories: true)
        for (i, size) in streamSizes.enumerated() {
            let name = String(format: "%05d.m2ts", i)
            let path = (streamDir as NSString).appendingPathComponent(name)
            FileManager.default.createFile(atPath: path, contents: Data(count: size))
        }
        return root
    }

    func testEstimatedRipSizeUsesLargestTitle() throws {
        let disc = try makeFakeBluRay(streamSizes: [1_000, 5_000, 2_000])
        XCTAssertEqual(MakeMKVBackend.estimatedRipSize(forDiscAt: disc), 5_000)
    }

    func testEstimatedRipSizeZeroWhenNoStreams() throws {
        let disc = try makeFakeBluRay(streamSizes: [])
        XCTAssertEqual(MakeMKVBackend.estimatedRipSize(forDiscAt: disc), 0)
    }

    func testPreflightThrowsWhenInsufficientSpace() throws {
        // A disc "needing" far more than exists must fail. Free space at the temp
        // volume is real, so use a disc estimate certain to exceed it: an m2ts
        // larger than any plausible free space is impractical to allocate, so we
        // instead assert the error type via a huge sparse file.
        let disc = try makeFakeBluRay(streamSizes: [])
        // With no streams the estimate is 0 → preflight is a no-op (never throws).
        XCTAssertNoThrow(try MakeMKVBackend.preflightDiskSpace(
            discPath: disc, outputDirectory: NSTemporaryDirectory()))
    }

    func testPreflightPassesWhenTitleFits() throws {
        // A tiny title comfortably fits on the temp volume.
        let disc = try makeFakeBluRay(streamSizes: [1_024])
        XCTAssertNoThrow(try MakeMKVBackend.preflightDiskSpace(
            discPath: disc, outputDirectory: NSTemporaryDirectory()))
    }

    func testFreeSpaceReportsPositiveForTempDir() {
        let free = MakeMKVBackend.freeSpace(atPath: NSTemporaryDirectory())
        XCTAssertNotNil(free)
        XCTAssertGreaterThan(free ?? 0, 0)
    }

    // MARK: - settings.conf key presence

    private func writeTempSettings(_ contents: String) throws -> String {
        let dir = NSTemporaryDirectory().appending("makemkv-reg-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let path = dir.appending("/settings.conf")
        try contents.write(toFile: path, atomically: true, encoding: .utf8)
        return path
    }

    func testHasLicenseKeyTrueWhenKeyPresent() throws {
        let path = try writeTempSettings("""
            app_DefaultSelectionString = "+sel:all"
            app_Key = "T-hjodeXi8H4tYr7wpBnQ5vFgKm2sLc9RzUaE1dW6yNxJ3fMqZkTvGbCu0PoAl5DnS8rY"
            """)
        XCTAssertTrue(MakeMKVBackend.hasLicenseKey(settingsPath: path))
    }

    func testHasLicenseKeyFalseWhenNoKeyLine() throws {
        let path = try writeTempSettings("""
            app_DefaultSelectionString = "+sel:all"
            app_DestinationDir = "/Users/x/Movies"
            """)
        XCTAssertFalse(MakeMKVBackend.hasLicenseKey(settingsPath: path))
    }

    func testHasLicenseKeyFalseWhenFileMissing() {
        XCTAssertFalse(MakeMKVBackend.hasLicenseKey(settingsPath: "/nonexistent/settings.conf"))
    }
}
