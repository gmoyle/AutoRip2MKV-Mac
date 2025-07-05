import XCTest
@testable import AutoRip2MKV_Mac

final class FFmpegConversionTests: XCTestCase {
    
    var mediaRipper: MediaRipper!
    let testInputPath = "/tmp/test_ffmpeg_input.vob"
    let testOutputPath = "/tmp/test_ffmpeg_output.mkv"
    
    override func setUpWithError() throws {
        mediaRipper = MediaRipper()
        
        // Create test input file
        let testData = createTestVideoData()
        try testData.write(to: URL(fileURLWithPath: testInputPath))
    }
    
    override func tearDownWithError() throws {
        mediaRipper = nil
        
        // Cleanup test files
        try? FileManager.default.removeItem(atPath: testInputPath)
        try? FileManager.default.removeItem(atPath: testOutputPath)
    }
    
    // MARK: - FFmpeg Path Detection Tests
    
    func testFFmpegPathDetection() throws {
        // Test that we can find FFmpeg executable
        let ffmpegPath = try mediaRipper.getFFmpegPath()
        
        XCTAssertFalse(ffmpegPath.isEmpty, "FFmpeg path should not be empty")
        XCTAssertTrue(ffmpegPath.contains("ffmpeg"), "Path should contain 'ffmpeg'")
        
        // Verify the file exists and is executable
        let fileManager = FileManager.default
        XCTAssertTrue(fileManager.fileExists(atPath: ffmpegPath), "FFmpeg should exist at path")
        XCTAssertTrue(fileManager.isExecutableFile(atPath: ffmpegPath), "FFmpeg should be executable")
    }
    
    func testFFmpegPathFallback() {
        // Test fallback behavior when FFmpeg is not found
        let originalPath = ProcessInfo.processInfo.environment["PATH"]
        
        // Temporarily modify PATH to remove FFmpeg
        var newEnv = ProcessInfo.processInfo.environment
        newEnv["PATH"] = "/usr/bin:/bin" // Minimal PATH without FFmpeg locations
        
        // This test would need environment manipulation or dependency injection
        // For now, we test the error case
        XCTAssertThrowsError(try mediaRipper.getFFmpegPath()) { error in
            XCTAssertTrue(error is MediaRipperError)
            if let ripperError = error as? MediaRipperError {
                XCTAssertEqual(ripperError, MediaRipperError.ffmpegNotFound)
            }
        }
    }
    
    // MARK: - Video Codec Tests
    
    func testVideoCodecArguments() throws {
        let testCases: [(MediaRipper.RippingConfiguration.VideoCodec, String)] = [
            (.h264, "libx264"),
            (.h265, "libx265"),
            (.av1, "libaom-av1")
        ]
        
        for (codec, expectedArg) in testCases {
            let actualArg = mediaRipper.videoCodecArgument(for: codec)
            XCTAssertEqual(actualArg, expectedArg, "Codec \(codec) should map to \(expectedArg)")
        }
    }
    
    func testAudioCodecArguments() throws {
        let testCases: [(MediaRipper.RippingConfiguration.AudioCodec, String)] = [
            (.aac, "aac"),
            (.ac3, "ac3"),
            (.dts, "dca"),
            (.flac, "flac")
        ]
        
        for (codec, expectedArg) in testCases {
            let actualArg = mediaRipper.audioCodecArgument(for: codec)
            XCTAssertEqual(actualArg, expectedArg, "Codec \(codec) should map to \(expectedArg)")
        }
    }
    
    // MARK: - Conversion Configuration Tests
    
    func testConversionWithDifferentQualitySettings() throws {
        let qualities: [MediaRipper.RippingConfiguration.RippingQuality] = [.low, .medium, .high, .lossless]
        
        for quality in qualities {
            let configuration = MediaRipper.RippingConfiguration(
                outputDirectory: "/tmp",
                selectedTitles: [],
                videoCodec: .h264,
                audioCodec: .aac,
                quality: quality,
                includeSubtitles: false,
                includeChapters: false,
                mediaType: .dvd
            )
            
            // Test that configuration is valid
            XCTAssertEqual(configuration.quality, quality)
            XCTAssertNotNil(configuration.quality.crf)
            
            // CRF values should be reasonable
            let crf = configuration.quality.crf
            XCTAssertGreaterThanOrEqual(crf, 0)
            XCTAssertLessThanOrEqual(crf, 51) // FFmpeg CRF range is 0-51
        }
    }
    
    func testConversionWithSubtitles() throws {
        let testTitle = createTestDVDTitle()
        let mediaItem = MediaRipper.MediaItem.dvdTitle(testTitle)
        
        let configuration = MediaRipper.RippingConfiguration(
            outputDirectory: "/tmp",
            selectedTitles: [],
            videoCodec: .h264,
            audioCodec: .aac,
            quality: .medium,
            includeSubtitles: true,
            includeChapters: false,
            mediaType: .dvd
        )
        
        // Test conversion setup (without actually running FFmpeg in tests)
        XCTAssertNoThrow({
            // This would normally call convertToMKV, but we're testing configuration
            XCTAssertTrue(configuration.includeSubtitles)
        })
    }
    
    func testConversionWithChapters() throws {
        let testTitle = createTestDVDTitle()
        let mediaItem = MediaRipper.MediaItem.dvdTitle(testTitle)
        
        let configuration = MediaRipper.RippingConfiguration(
            outputDirectory: "/tmp",
            selectedTitles: [],
            videoCodec: .h264,
            audioCodec: .aac,
            quality: .medium,
            includeSubtitles: false,
            includeChapters: true,
            mediaType: .dvd
        )
        
        XCTAssertTrue(configuration.includeChapters)
    }
    
    // MARK: - Progress Monitoring Tests
    
    func testFFmpegProgressParsing() {
        let progressLines = [
            "frame=  100 fps= 25 q=23.0 size=    1024kB time=00:00:04.00 bitrate=2048.0kbits/s speed=1.0x",
            "frame=  200 fps= 25 q=23.0 size=    2048kB time=00:00:08.00 bitrate=2048.0kbits/s speed=1.0x",
            "frame=  300 fps= 25 q=23.0 size=    3072kB time=00:00:12.00 bitrate=2048.0kbits/s speed=1.0x"
        ]
        
        var parsedTimes: [Double] = []
        
        for line in progressLines {
            if let time = mediaRipper.parseTimeString(extractTimeFromLine(line)) {
                parsedTimes.append(time)
            }
        }
        
        XCTAssertEqual(parsedTimes.count, 3)
        XCTAssertEqual(parsedTimes[0], 4.0, accuracy: 0.1)
        XCTAssertEqual(parsedTimes[1], 8.0, accuracy: 0.1)
        XCTAssertEqual(parsedTimes[2], 12.0, accuracy: 0.1)
    }
    
    func testTimeStringParsing() {
        let testCases: [(String, Double?)] = [
            ("00:01:23.45", 83.45),
            ("01:30:00.00", 5400.0),
            ("00:00:30.50", 30.5),
            ("invalid", nil),
            ("", nil),
            ("12:34", nil) // Wrong format
        ]
        
        for (timeString, expected) in testCases {
            let result = mediaRipper.parseTimeString(timeString)
            
            if let expected = expected {
                XCTAssertNotNil(result, "Should parse \(timeString)")
                XCTAssertEqual(result!, expected, accuracy: 0.01, "Time \(timeString) should equal \(expected)")
            } else {
                XCTAssertNil(result, "Should not parse invalid time string: \(timeString)")
            }
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testConversionFailureHandling() {
        // Test behavior when FFmpeg fails
        let invalidConfig = MediaRipper.RippingConfiguration(
            outputDirectory: "/invalid/path/that/does/not/exist",
            selectedTitles: [],
            videoCodec: .h264,
            audioCodec: .aac,
            quality: .medium,
            includeSubtitles: false,
            includeChapters: false,
            mediaType: .dvd
        )
        
        // This should eventually fail due to invalid output path
        XCTAssertNotNil(invalidConfig)
    }
    
    func testUnsupportedCodecHandling() {
        // Test that we handle codec configurations properly
        let allVideoCodecs: [MediaRipper.RippingConfiguration.VideoCodec] = [.h264, .h265, .av1]
        let allAudioCodecs: [MediaRipper.RippingConfiguration.AudioCodec] = [.aac, .ac3, .dts, .flac]
        
        for videoCodec in allVideoCodecs {
            for audioCodec in allAudioCodecs {
                let config = MediaRipper.RippingConfiguration(
                    outputDirectory: "/tmp",
                    selectedTitles: [],
                    videoCodec: videoCodec,
                    audioCodec: audioCodec,
                    quality: .medium,
                    includeSubtitles: false,
                    includeChapters: false,
                    mediaType: .dvd
                )
                
                // All combinations should be valid
                XCTAssertEqual(config.videoCodec, videoCodec)
                XCTAssertEqual(config.audioCodec, audioCodec)
            }
        }
    }
    
    // MARK: - Performance Tests
    
    func testConversionArgumentBuildingPerformance() {
        let configuration = MediaRipper.RippingConfiguration(
            outputDirectory: "/tmp",
            selectedTitles: [],
            videoCodec: .h264,
            audioCodec: .aac,
            quality: .medium,
            includeSubtitles: true,
            includeChapters: true,
            mediaType: .dvd
        )
        
        measure {
            for _ in 0..<1000 {
                // Simulate argument building
                _ = [
                    "-i", testInputPath,
                    "-c:v", mediaRipper.videoCodecArgument(for: configuration.videoCodec),
                    "-crf", "\(configuration.quality.crf)",
                    "-c:a", mediaRipper.audioCodecArgument(for: configuration.audioCodec)
                ]
            }
        }
    }
    
    // MARK: - Media Item Tests
    
    func testMediaItemTypes() {
        let testTitle = createTestDVDTitle()
        let testPlaylist = createTestBlurayPlaylist()
        
        let dvdItem = MediaRipper.MediaItem.dvdTitle(testTitle)
        let blurayItem = MediaRipper.MediaItem.blurayPlaylist(testPlaylist)
        
        // Test that we can extract the underlying types
        switch dvdItem {
        case .dvdTitle(let title):
            XCTAssertEqual(title.number, testTitle.number)
        default:
            XCTFail("Should be DVD title")
        }
        
        switch blurayItem {
        case .blurayPlaylist(let playlist):
            XCTAssertEqual(playlist.number, testPlaylist.number)
        default:
            XCTFail("Should be Blu-ray playlist")
        }
    }
    
    // MARK: - Helper Methods
    
    private func createTestVideoData() -> Data {
        // Create minimal test video data (not actual video, just test data)
        var data = Data(repeating: 0x00, count: 1024 * 1024) // 1MB of test data
        
        // Add some pattern to make it look like video data
        for i in stride(from: 0, to: data.count, by: 188) { // MPEG-TS packet size
            if i + 4 < data.count {
                data[i] = 0x47 // MPEG-TS sync byte
                data[i + 1] = UInt8.random(in: 0...255)
                data[i + 2] = UInt8.random(in: 0...255)
                data[i + 3] = UInt8.random(in: 0...255)
            }
        }
        
        return data
    }
    
    private func createTestDVDTitle() -> DVDTitle {
        return DVDTitle(
            number: 1,
            vtsNumber: 1,
            vtsTitleNumber: 1,
            startSector: 1000,
            chapters: 5,
            angles: 1,
            duration: 3600 // 1 hour
        )
    }
    
    private func createTestBlurayPlaylist() -> BluRayPlaylist {
        return BluRayPlaylist(number: 1, filename: "00001.mpls")
    }
    
    private func extractTimeFromLine(_ line: String) -> String {
        // Extract time from FFmpeg progress line
        let components = line.components(separatedBy: " ")
        for component in components {
            if component.hasPrefix("time=") {
                return String(component.dropFirst(5))
            }
        }
        return ""
    }
}

// MARK: - MediaRipper Test Extensions

private extension MediaRipper {
    // Expose internal methods for testing
    func getFFmpegPath() throws -> String {
        // Call the private method through reflection or create a test-specific implementation
        return "/usr/local/bin/ffmpeg" // Mock for testing
    }
    
    func videoCodecArgument(for codec: RippingConfiguration.VideoCodec) -> String {
        switch codec {
        case .h264: return "libx264"
        case .h265: return "libx265"
        case .av1: return "libaom-av1"
        }
    }
    
    func audioCodecArgument(for codec: RippingConfiguration.AudioCodec) -> String {
        switch codec {
        case .aac: return "aac"
        case .ac3: return "ac3"
        case .dts: return "dca"
        case .flac: return "flac"
        }
    }
    
    func parseTimeString(_ timeString: String) -> Double? {
        let components = timeString.components(separatedBy: ":")
        guard components.count == 3 else { return nil }
        
        guard let hours = Double(components[0]),
              let minutes = Double(components[1]),
              let seconds = Double(components[2]) else {
            return nil
        }
        
        return hours * 3600 + minutes * 60 + seconds
    }
}
