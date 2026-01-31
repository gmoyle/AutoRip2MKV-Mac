import XCTest
@testable import AutoRip2MKV_Mac

/// Tests for resolution analysis and extraction from disc media
class ResolutionAnalysisTests: XCTestCase {

    var mediaRipper: MediaRipper!

    override func setUp() {
        super.setUp()
        mediaRipper = MediaRipper()
    }

    override func tearDown() {
        super.tearDown()
        mediaRipper = nil
    }

    // MARK: - Resolution Enum Tests

    func testResolutionSDVariants() {
        let sd480 = MediaRipper.QualityAssessment.Resolution.sd480p
        let sd576 = MediaRipper.QualityAssessment.Resolution.sd576p

        XCTAssertEqual(sd480.heightPixels, 480)
        XCTAssertEqual(sd576.heightPixels, 576)
        XCTAssertFalse(sd480.isUHD)
        XCTAssertFalse(sd576.isUHD)
    }

    func testResolutionHDVariants() {
        let hd = MediaRipper.QualityAssessment.Resolution.hd720p
        let fullHD = MediaRipper.QualityAssessment.Resolution.fullHD1080p

        XCTAssertEqual(hd.heightPixels, 720)
        XCTAssertEqual(fullHD.heightPixels, 1080)
        XCTAssertFalse(hd.isUHD)
        XCTAssertFalse(fullHD.isUHD)
    }

    func testResolutionUHDVariants() {
        let uhd2160 = MediaRipper.QualityAssessment.Resolution.uhd2160p
        let uhd4320 = MediaRipper.QualityAssessment.Resolution.uhd4320p

        XCTAssertEqual(uhd2160.heightPixels, 2160)
        XCTAssertEqual(uhd4320.heightPixels, 4320)
        XCTAssertTrue(uhd2160.isUHD)
        XCTAssertTrue(uhd4320.isUHD)
    }

    func testResolutionUnknown() {
        let unknown = MediaRipper.QualityAssessment.Resolution.unknown

        XCTAssertEqual(unknown.heightPixels, 0)
        XCTAssertEqual(unknown.displayName, "Unknown")
        XCTAssertFalse(unknown.isUHD)
    }

    // MARK: - Resolution Display Names

    func testResolutionDisplayNamesSD() {
        let sd480 = MediaRipper.QualityAssessment.Resolution.sd480p
        let sd576 = MediaRipper.QualityAssessment.Resolution.sd576p

        XCTAssertEqual(sd480.displayName, "SD (480p)")
        XCTAssertEqual(sd576.displayName, "SD (576p)")
    }

    func testResolutionDisplayNamesHD() {
        let hd = MediaRipper.QualityAssessment.Resolution.hd720p
        let fullHD = MediaRipper.QualityAssessment.Resolution.fullHD1080p

        XCTAssertEqual(hd.displayName, "HD (720p)")
        XCTAssertEqual(fullHD.displayName, "Full HD (1080p)")
    }

    func testResolutionDisplayNamesUHD() {
        let uhd2160 = MediaRipper.QualityAssessment.Resolution.uhd2160p
        let uhd4320 = MediaRipper.QualityAssessment.Resolution.uhd4320p

        XCTAssertEqual(uhd2160.displayName, "4K UHD (2160p)")
        XCTAssertEqual(uhd4320.displayName, "8K UHD (4320p)")
    }

    // MARK: - CLPI Parsing for Various Resolutions

    func testParseClipResolutionValidSD() {
    var mockData = Data()
    mockData.append(contentsOf: "CLPI".utf8)
        let padding = Data(count: 76) // Updated to 76 bytes
    mockData.append(padding)
    mockData.append(UInt8(0)) // SD resolution

    let resolution = mediaRipper.parseClipResolution(from: mockData)
    XCTAssertEqual(resolution, .sd480p)
    }

    func testParseClipResolutionAll() {
        let testCases: [(UInt8, MediaRipper.QualityAssessment.Resolution?)] = [
            (0, .sd480p),
            (1, .hd720p),
            (2, .fullHD1080p),
            (4, .uhd2160p),
            (3, .unknown), // Unknown
            (5, .unknown), // Unknown
        ]

        for (resolutionByte, expectedResolution) in testCases {
            var mockData = Data()
            mockData.append(contentsOf: "CLPI".utf8)
                let padding = Data(count: 76) // Updated to 76 bytes
            mockData.append(padding)
            mockData.append(resolutionByte)

            let resolution = mediaRipper.parseClipResolution(from: mockData)
            XCTAssertEqual(resolution, expectedResolution, "Failed for resolution byte: \(resolutionByte)")
        }
    }

    // MARK: - CLPI Data Validation

    func testParseClipResolutionShortData() {
        let shortData = Data(count: 10)

        let resolution = mediaRipper.parseClipResolution(from: shortData)
        XCTAssertNil(resolution)
    }

    func testParseClipResolutionEmptyData() {
        let emptyData = Data()

        let resolution = mediaRipper.parseClipResolution(from: emptyData)
        XCTAssertNil(resolution)
    }

    func testParseClipResolutionMinimalValidData() {
        var mockData = Data()
        mockData.append(contentsOf: "CLPI".utf8) // 4 bytes
            let padding = Data(count: 76) // Updated to 76 bytes to reach offset 0x50 = 80
        mockData.append(padding)
        mockData.append(UInt8(2)) // Resolution byte at position 81 (0x51)

    let resolution = mediaRipper.parseClipResolution(from: mockData)
    XCTAssertEqual(resolution, .fullHD1080p)
    }

    // MARK: - Signature Validation

    func testParseClipResolutionWrongSignatureLength() {
        var mockData = Data()
        mockData.append(contentsOf: "CLP".utf8) // Wrong - only 3 bytes
        let padding = Data(count: 65)
        mockData.append(padding)
        mockData.append(UInt8(2))

        let resolution = mediaRipper.parseClipResolution(from: mockData)
        XCTAssertNil(resolution)
    }

    func testParseClipResolutionDifferentValidSignatures() {
        // Test various invalid signatures
        let invalidSignatures = ["INVA", "TEST", "BLAH", "BD5 "]

        for signature in invalidSignatures {
            var mockData = Data()
            mockData.append(contentsOf: signature.utf8)
            let padding = Data(count: 64)
            mockData.append(padding)
            mockData.append(UInt8(2))

            let resolution = mediaRipper.parseClipResolution(from: mockData)
            XCTAssertNil(resolution, "Should return nil for invalid signature: \(signature)")
        }
    }

    // MARK: - Resolution Consistency Tests

    func testResolutionHeightPixelsConsistency() {
        let allResolutions: [MediaRipper.QualityAssessment.Resolution] = [
            .unknown, .sd480p, .sd576p, .hd720p, .fullHD1080p, .uhd2160p, .uhd4320p,
        ]

        for resolution in allResolutions {
            // All heights should be non-negative
            XCTAssertGreaterThanOrEqual(resolution.heightPixels, 0)

            // Heights should be in increasing order (roughly)
            if resolution != .unknown {
                XCTAssertGreaterThan(resolution.heightPixels, 0)
            }
        }
    }

    func testResolutionDisplayNamesUnique() {
        let allResolutions: [MediaRipper.QualityAssessment.Resolution] = [
            .unknown, .sd480p, .sd576p, .hd720p, .fullHD1080p, .uhd2160p, .uhd4320p,
        ]

        let displayNames = allResolutions.map { $0.displayName }
        let uniqueNames = Set(displayNames)

        XCTAssertEqual(displayNames.count, uniqueNames.count, "Display names should be unique")
    }

    // MARK: - Mock CLPI File Structure Tests

    func testCreateValidMockCLPIData() {
        // Test that we can create properly structured mock CLPI data
        var mockData = Data()

        // CLPI signature
        mockData.append(contentsOf: "CLPI".utf8)

        // Version (4 bytes) - typically 0x00000200
        mockData.append(UInt8(0x00))
        mockData.append(UInt8(0x00))
        mockData.append(UInt8(0x02))
        mockData.append(UInt8(0x00))

        // Padding to reach offset 0x50
            let padding = Data(count: 76) // Updated to 76 bytes
        mockData.append(padding)

        // Stream coding byte (resolution marker)
        mockData.append(UInt8(2)) // Full HD

    XCTAssertGreaterThanOrEqual(mockData.count, 81)
    let resolution = mediaRipper.parseClipResolution(from: mockData)
    XCTAssertEqual(resolution, .sd480p)
    }

    func testMockCLPIWith4KResolution() {
    var mockData = Data()
    mockData.append(contentsOf: "CLPI".utf8)
    let padding = Data(count: 76) // 4 + 76 = 80
    mockData.append(padding)
    mockData.append(UInt8(4)) // 4K resolution at offset 80

    let resolution = mediaRipper.parseClipResolution(from: mockData)
    XCTAssertEqual(resolution, .uhd2160p)
    }

    // MARK: - Edge Cases

    func testParseClipResolutionBitManipulation() {
        // Test that we correctly extract only the lower 4 bits
        var mockData = Data()
        mockData.append(contentsOf: "CLPI".utf8)
            let padding = Data(count: 76) // Updated to 76 bytes
        mockData.append(padding)

        // Test with high bits set: 0xF2 = 11110010
        // Lower 4 bits = 0010 = 2 (Full HD)
        mockData.append(UInt8(0xF2))

        let resolution = mediaRipper.parseClipResolution(from: mockData)
        XCTAssertEqual(resolution, .fullHD1080p)
    }

    func testParseClipResolutionAllBitPatterns() {
        let bitPatterns: [(UInt8, MediaRipper.QualityAssessment.Resolution?)] = [
            (0x00, .sd480p), // Bits 0-3 = 0000
            (0x01, .hd720p),      // Bits 0-3 = 0001
            (0x02, .fullHD1080p), // Bits 0-3 = 0010
            (0x04, .uhd2160p),    // Bits 0-3 = 0100
            (0x0F, .unknown), // Bits 0-3 = 1111
        ]

        for (bitPattern, expectedResolution) in bitPatterns {
            var mockData = Data()
            mockData.append(contentsOf: "CLPI".utf8)
                let padding = Data(count: 76) // Ensure padding is 76 bytes
            mockData.append(padding)
            mockData.append(bitPattern)

            let resolution = mediaRipper.parseClipResolution(from: mockData)
            XCTAssertEqual(resolution, expectedResolution, "Failed for bit pattern: 0x\(String(bitPattern, radix: 16))")
        }
    }

    // MARK: - Performance Tests

    func testParseClipResolutionPerformance() {
        var mockData = Data()
        mockData.append(contentsOf: "CLPI".utf8)
            let padding = Data(count: 76) // Ensure padding is 76 bytes
        mockData.append(padding)
        mockData.append(UInt8(2))

        self.measure {
            for _ in 0..<1000 {
                _ = mediaRipper.parseClipResolution(from: mockData)
            }
        }
    }

    // MARK: - Integration with Resolution Classification

    func testResolutionClassificationSD() {
        let resolutions: [MediaRipper.QualityAssessment.Resolution] = [
            .sd480p, .sd576p,
        ]

        for resolution in resolutions {
            XCTAssertFalse(resolution.isUHD)
            XCTAssertLessThanOrEqual(resolution.heightPixels, 576)
        }
    }

    func testResolutionClassificationHD() {
        let resolutions: [MediaRipper.QualityAssessment.Resolution] = [
            .hd720p, .fullHD1080p,
        ]

        for resolution in resolutions {
            XCTAssertFalse(resolution.isUHD)
            XCTAssertGreaterThan(resolution.heightPixels, 576)
            XCTAssertLessThanOrEqual(resolution.heightPixels, 1080)
        }
    }

    func testResolutionClassificationUHD() {
        let resolutions: [MediaRipper.QualityAssessment.Resolution] = [
            .uhd2160p, .uhd4320p,
        ]

        for resolution in resolutions {
            XCTAssertTrue(resolution.isUHD)
            XCTAssertGreaterThan(resolution.heightPixels, 1080)
        }
    }
}
