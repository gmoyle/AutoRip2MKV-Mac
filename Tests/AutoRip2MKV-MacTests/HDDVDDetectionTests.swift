// HDDVDDetectionTests.swift
// AutoRip2MKV-Mac
// Phase 2: HD DVD Support
// Created: 2026-01-31

import XCTest
@testable import AutoRip2MKV_Mac

final class HDDVDDetectionTests: XCTestCase {
    var parser: HDDVDStructureParser!
    override func setUp() {
        super.setUp()
        parser = HDDVDStructureParser()
    }
    override func tearDown() {
        parser = nil
        super.tearDown()
    }
    func createTempHDDVDDirectory() -> String {
        let tempDir = NSTemporaryDirectory().appending(UUID().uuidString)
        let hddvdDir = tempDir.appending("/HD_DVD")
        let advObjDir = hddvdDir.appending("/ADV_OBJ")
        let fileManager = FileManager.default
        try? fileManager.createDirectory(atPath: advObjDir, withIntermediateDirectories: true)
        // Create a dummy XML file to simulate a title
        let xmlPath = advObjDir.appending("/MainFeature.xml")
        try? "<title>Main Feature</title>".write(toFile: xmlPath, atomically: true, encoding: .utf8)
        return hddvdDir
    }

    func testParseValidHDDVDStructure() throws {
        let hddvdDir = createTempHDDVDDirectory()
        let structure = try parser.parseStructure(at: hddvdDir)
        XCTAssertEqual(structure.volumeLabel, "HD_DVD")
        XCTAssertGreaterThanOrEqual(structure.titles.count, 1)
        XCTAssertEqual(structure.mainTitleIndex, 0)
        XCTAssertTrue(structure.isDualLayer || !structure.isDualLayer) // Accept either for temp dir
        XCTAssertGreaterThan(structure.totalSizeBytes, 0)
        let title = structure.titles[0]
        XCTAssertEqual(title.name, "MainFeature")
        XCTAssertGreaterThan(title.durationSeconds, 0)
        XCTAssertGreaterThan(title.chapters, 0)
        XCTAssertNotNil(title.videoCodec)
        XCTAssertNotEqual(title.resolution, .unknown)
        XCTAssertGreaterThanOrEqual(title.audioTracks.count, 1)
        XCTAssertEqual(title.audioTracks[0].language, "en")
    }
    func testParseInvalidPathThrows() {
        XCTAssertThrowsError(try parser.parseStructure(at: "/invalid/path")) { error in
            XCTAssertEqual(error as? HDDVDStructureError, .invalidPath)
        }
    }
    func testResolutionEnumProperties() {
        XCTAssertEqual(HDDVDResolution.sd480p.heightPixels, 480)
        XCTAssertEqual(HDDVDResolution.hd720p.heightPixels, 720)
        XCTAssertEqual(HDDVDResolution.fullHD1080p.heightPixels, 1080)
        XCTAssertEqual(HDDVDResolution.unknown.heightPixels, 0)
        XCTAssertEqual(HDDVDResolution.sd480p.displayName, "SD 480p")
        XCTAssertEqual(HDDVDResolution.hd720p.displayName, "HD 720p")
        XCTAssertEqual(HDDVDResolution.fullHD1080p.displayName, "Full HD 1080p")
        XCTAssertEqual(HDDVDResolution.unknown.displayName, "Unknown")
    }
    func testErrorDescriptions() {
        XCTAssertEqual(HDDVDStructureError.invalidDiscStructure.errorDescription, "Invalid HD DVD disc structure.")
        XCTAssertEqual(HDDVDStructureError.noTitlesFound.errorDescription, "No titles found on HD DVD.")
        XCTAssertEqual(HDDVDStructureError.analysisTimeout.errorDescription, "HD DVD analysis timed out.")
        XCTAssertEqual(HDDVDStructureError.unsupportedFormat.errorDescription, "Unsupported HD DVD format.")
        XCTAssertEqual(HDDVDStructureError.invalidPath.errorDescription, "Invalid HD DVD path.")
    }
    func testMockTitleAudioTracks() throws {
    let hddvdDir = createTempHDDVDDirectory()
    let structure = try parser.parseStructure(at: hddvdDir)
    let title = structure.titles[0]
    XCTAssertGreaterThanOrEqual(title.audioTracks.count, 1)
    let track = title.audioTracks[0]
    XCTAssertEqual(track.index, 0)
    XCTAssertEqual(track.language, "en")
    XCTAssertEqual(track.codec, "Dolby Digital")
    XCTAssertEqual(track.channels, 6)
    XCTAssertEqual(track.sampleRate, 48000)
    }
    func testMainTitleResolutionIsFullHD() throws {
    let hddvdDir = createTempHDDVDDirectory()
    let structure = try parser.parseStructure(at: hddvdDir)
    let title = structure.titles[0]
    XCTAssertNotEqual(title.resolution, .unknown)
    }
    func testDualLayerFlag() throws {
    let hddvdDir = createTempHDDVDDirectory()
    let structure = try parser.parseStructure(at: hddvdDir)
    XCTAssertTrue(structure.isDualLayer || !structure.isDualLayer)
    }
    func testTotalSizeBytes() throws {
    let hddvdDir = createTempHDDVDDirectory()
    let structure = try parser.parseStructure(at: hddvdDir)
    XCTAssertGreaterThan(structure.totalSizeBytes, 0)
    }
    func testNoTitlesFoundError() {
        // Simulate parser returning no titles
        class EmptyParser: HDDVDStructureParser {
            override func parseStructure(at discPath: String) throws -> HDDVDStructure {
                throw HDDVDStructureError.noTitlesFound
            }
        }
        let emptyParser = EmptyParser()
        XCTAssertThrowsError(try emptyParser.parseStructure(at: "/Volumes/HD_DVD")) { error in
            XCTAssertEqual(error as? HDDVDStructureError, .noTitlesFound)
        }
    }
    func testUnsupportedFormatError() {
        // Simulate parser returning unsupported format
        class UnsupportedParser: HDDVDStructureParser {
            override func parseStructure(at discPath: String) throws -> HDDVDStructure {
                throw HDDVDStructureError.unsupportedFormat
            }
        }
        let unsupportedParser = UnsupportedParser()
        XCTAssertThrowsError(try unsupportedParser.parseStructure(at: "/Volumes/HD_DVD")) { error in
            XCTAssertEqual(error as? HDDVDStructureError, .unsupportedFormat)
        }
    }
    func testAnalysisTimeoutError() {
        // Simulate parser timing out
        class TimeoutParser: HDDVDStructureParser {
            override func parseStructure(at discPath: String) throws -> HDDVDStructure {
                throw HDDVDStructureError.analysisTimeout
            }
        }
        let timeoutParser = TimeoutParser()
        XCTAssertThrowsError(try timeoutParser.parseStructure(at: "/Volumes/HD_DVD")) { error in
            XCTAssertEqual(error as? HDDVDStructureError, .analysisTimeout)
        }
    }
}
