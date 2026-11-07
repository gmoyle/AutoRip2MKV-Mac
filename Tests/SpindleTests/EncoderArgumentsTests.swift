import XCTest
@testable import Spindle

final class EncoderArgumentsTests: XCTestCase {

    private let ripper = MediaRipper()

    private func config(codec: MediaRipper.RippingConfiguration.VideoCodec = .h264,
                        audio: MediaRipper.RippingConfiguration.AudioCodec = .aac,
                        quality: MediaRipper.RippingConfiguration.RippingQuality = .medium,
                        hardware: Bool) -> MediaRipper.RippingConfiguration {
        MediaRipper.RippingConfiguration(
            outputDirectory: "/tmp", selectedTitles: [], videoCodec: codec, audioCodec: audio,
            quality: quality, includeSubtitles: false, includeChapters: false, mediaType: .dvd,
            hardwareAcceleration: hardware)
    }

    func testSoftwareEncoderWhenHardwareAccelerationOff() {
        let args = ripper.videoEncoderArguments(for: config(hardware: false))
        XCTAssertEqual(Array(args.prefix(2)), ["-c:v", "libx264"])
        XCTAssertTrue(args.contains("-crf"))
    }

    func testVideoToolboxWhenHardwareAccelerationOn() throws {
        #if arch(arm64)
        let args = ripper.videoEncoderArguments(for: config(codec: .h265, hardware: true))
        XCTAssertEqual(args, ["-c:v", "hevc_videotoolbox", "-q:v", "55", "-a53cc", "0"])
        #else
        throw XCTSkip("VideoToolbox constant-quality mode is Apple Silicon only")
        #endif
    }

    func testHardwareFallsBackToSoftwareWhenVTCannotHonorRequest() {
        // No VT encoder for AV1, and lossless needs the software path.
        XCTAssertEqual(ripper.videoEncoderArguments(for: config(codec: .av1, hardware: true)).prefix(2),
                       ["-c:v", "libaom-av1"])
        XCTAssertEqual(ripper.videoEncoderArguments(for: config(quality: .lossless, hardware: true)).prefix(2),
                       ["-c:v", "libx264"])
    }

    func testDTSEncoderIsMarkedExperimental() {
        XCTAssertEqual(ripper.audioEncoderArguments(for: .dts), ["-c:a", "dca", "-strict", "-2"])
        XCTAssertEqual(ripper.audioEncoderArguments(for: .aac), ["-c:a", "aac"])
    }

    func testFingerprintOnlyIncludesHardwareAccelerationWhenOn() {
        XCTAssertNil(ConversionQueue.settingsFingerprint(of: config(hardware: false))["hardwareAcceleration"])
        XCTAssertEqual(ConversionQueue.settingsFingerprint(of: config(hardware: true))["hardwareAcceleration"], "true")
    }
}
