import XCTest
@testable import AutoRip2MKV_Mac

/// An Intel-only ffmpeg under Rosetta can't run VideoToolbox constant-quality
/// encodes; these cover detecting that and falling back to software.
final class FFmpegArchitectureTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FFmpegArchitectureTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    private func writeHeader(_ bytes: [UInt8], name: String) throws -> String {
        let url = tempDir.appendingPathComponent(name)
        try Data(bytes + [UInt8](repeating: 0, count: 64)).write(to: url)
        return url.path
    }

    // MH_MAGIC_64 (little-endian) followed by cputype
    private let thinX86: [UInt8] = [0xCF, 0xFA, 0xED, 0xFE, 0x07, 0x00, 0x00, 0x01]
    private let thinARM64: [UInt8] = [0xCF, 0xFA, 0xED, 0xFE, 0x0C, 0x00, 0x00, 0x01]

    private func fatHeader(cpuTypes: [UInt32]) -> [UInt8] {
        var bytes: [UInt8] = [0xCA, 0xFE, 0xBA, 0xBE]
        func be(_ v: UInt32) -> [UInt8] { [UInt8(v >> 24), UInt8((v >> 16) & 0xFF), UInt8((v >> 8) & 0xFF), UInt8(v & 0xFF)] }
        bytes += be(UInt32(cpuTypes.count))
        for cpu in cpuTypes { bytes += be(cpu) + [UInt8](repeating: 0, count: 16) }  // 20-byte fat_arch
        return bytes
    }

    func testDetectsThinBinaries() throws {
        XCTAssertFalse(MediaRipper.binarySupportsArm64(atPath: try writeHeader(thinX86, name: "x86")))
        XCTAssertTrue(MediaRipper.binarySupportsArm64(atPath: try writeHeader(thinARM64, name: "arm64")))
    }

    func testDetectsUniversalBinaries() throws {
        let universal = try writeHeader(fatHeader(cpuTypes: [0x0100_0007, 0x0100_000C]), name: "universal")
        let intelOnlyFat = try writeHeader(fatHeader(cpuTypes: [0x0100_0007]), name: "fat-x86")
        XCTAssertTrue(MediaRipper.binarySupportsArm64(atPath: universal))
        XCTAssertFalse(MediaRipper.binarySupportsArm64(atPath: intelOnlyFat))
    }

    func testNonMachOAndMissingFilesAreNotArm64() throws {
        XCTAssertFalse(MediaRipper.binarySupportsArm64(atPath: try writeHeader([0x50, 0x4B, 0x03, 0x04], name: "zip")))
        XCTAssertFalse(MediaRipper.binarySupportsArm64(atPath: tempDir.appendingPathComponent("nope").path))
    }

    func testSystemBinaryIsNative() {
        XCTAssertTrue(MediaRipper.isNativeBinary(atPath: "/bin/ls"))
    }

    func testIntelFFmpegGetsSoftwareEncoderEvenWithHardwareAcceleration() throws {
        #if arch(arm64)
        let ripper = MediaRipper()
        let config = MediaRipper.RippingConfiguration(
            outputDirectory: "/tmp", selectedTitles: [], videoCodec: .h264, audioCodec: .aac,
            quality: .high, includeSubtitles: false, includeChapters: false, mediaType: .dvd,
            hardwareAcceleration: true)
        let intel = try writeHeader(thinX86, name: "ffmpeg-x86")
        let native = try writeHeader(thinARM64, name: "ffmpeg-arm64")
        XCTAssertEqual(Array(ripper.videoEncoderArguments(for: config, ffmpegPath: intel).prefix(2)),
                       ["-c:v", "libx264"])
        XCTAssertEqual(ripper.videoEncoderArguments(for: config, ffmpegPath: native),
                       ["-c:v", "h264_videotoolbox", "-q:v", "65"])
        #else
        throw XCTSkip("Rosetta only applies on Apple Silicon")
        #endif
    }
}

/// The DVD read must start at the title VOB's real disc location and refuse
/// data that isn't an MPEG program stream.
final class DVDReadLocationTests: XCTestCase {

    func testPackHeaderDetection() {
        XCTAssertTrue(MediaRipper.isMPEGPackHeader(Data([0x00, 0x00, 0x01, 0xBA, 0x44])))
        XCTAssertFalse(MediaRipper.isMPEGPackHeader(Data(count: 2048)))                          // zero-filled
        XCTAssertFalse(MediaRipper.isMPEGPackHeader(Data([0x01, 0x00, 0x02, 0x00, 0x66])))      // UDF descriptor tag
        XCTAssertFalse(MediaRipper.isMPEGPackHeader(Data()))
    }

    func testPhysicalStartSectorOfLocalFile() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("l2p-\(UUID().uuidString)")
        try Data(repeating: 0xAB, count: 64 * 1024).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertNotNil(MediaRipper.physicalStartSector(ofFile: url.path))
        XCTAssertNil(MediaRipper.physicalStartSector(ofFile: url.path + ".missing"))
    }

    func testTitleWithoutVOBFilesHasNoDiscLocation() {
        let title = DVDTitle(number: 1, vtsNumber: 1, vtsTitleNumber: 1, startSector: 23,
                             chapters: 1, angles: 1, duration: 0)
        XCTAssertThrowsError(try MediaRipper().discStartSector(of: title))
    }
}
