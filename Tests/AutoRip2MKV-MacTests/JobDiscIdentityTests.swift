import XCTest
@testable import AutoRip2MKV_Mac

/// The rip-history record is written after encoding, once the disc has been
/// ejected. The job must carry the identity computed while the disc was mounted,
/// or the record falls back to the bare label and re-inserting the disc re-rips it.
final class JobDiscIdentityTests: XCTestCase {

    func testJobKeepsFingerprintedIdentityAfterDiscIsGone() throws {
        let disc = FileManager.default.temporaryDirectory
            .appendingPathComponent("JobDiscIdentityTests-\(UUID().uuidString)/THE_GOONIES")
        let videoTS = disc.appendingPathComponent("VIDEO_TS")
        try FileManager.default.createDirectory(at: videoTS, withIntermediateDirectories: true)
        try Data(count: 4096).write(to: videoTS.appendingPathComponent("VTS_01_1.VOB"))
        try Data(count: 2048).write(to: videoTS.appendingPathComponent("VTS_01_0.VOB"))

        let mountedIdentity = DiscIdentity.compute(forDiscAt: disc.path)
        XCTAssertTrue(mountedIdentity.hasPrefix("THE_GOONIES#"))

        let config = MediaRipper.RippingConfiguration(
            outputDirectory: "/tmp", selectedTitles: [], videoCodec: .h264, audioCodec: .aac,
            quality: .high, includeSubtitles: false, includeChapters: false, mediaType: .dvd)
        let job = ConversionQueue.ConversionJob(
            sourcePath: disc.path, outputDirectory: "/tmp", configuration: config,
            mediaType: .dvd, discTitle: "The Goonies (1985)")

        // "Eject": the mount point disappears before the record is written.
        try FileManager.default.removeItem(at: disc.deletingLastPathComponent())
        XCTAssertEqual(DiscIdentity.compute(forDiscAt: disc.path), "THE_GOONIES")  // what the old code recorded

        XCTAssertEqual(job.discIdentity, mountedIdentity)
    }
}
