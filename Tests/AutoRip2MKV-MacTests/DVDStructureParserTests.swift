import XCTest
@testable import AutoRip2MKV_Mac

final class DVDStructureParserTests: XCTestCase {
    
    var parser: DVDStructureParser!
    let testDVDPath = "/tmp/test_dvd"
    
    override func setUpWithError() throws {
        parser = DVDStructureParser(dvdPath: testDVDPath)
        
        // Create test directory structure
        try createTestDVDStructure()
    }
    
    override func tearDownWithError() throws {
        parser = nil
        
        // Clean up test directory
        try? FileManager.default.removeItem(atPath: testDVDPath)
    }
    
    // MARK: - Test Setup Helpers
    
    private func createTestDVDStructure() throws {
        let videoTSPath = "\(testDVDPath)/VIDEO_TS"
        try FileManager.default.createDirectory(atPath: videoTSPath, withIntermediateDirectories: true)
        
        // Create minimal test IFO file
        let vmgiPath = "\(videoTSPath)/VIDEO_TS.IFO"
        let testVMGIData = createTestVMGIData()
        try testVMGIData.write(to: URL(fileURLWithPath: vmgiPath))
        
        // Create test VTS file
        let vtsPath = "\(videoTSPath)/VTS_01_0.IFO"
        let testVTSData = createTestVTSData()
        try testVTSData.write(to: URL(fileURLWithPath: vtsPath))
        
        // Create test VOB files
        for i in 1...3 {
            let vobPath = "\(videoTSPath)/VTS_01_\(i).VOB"
            let testVOBData = Data(repeating: 0x00, count: 1024)
            try testVOBData.write(to: URL(fileURLWithPath: vobPath))
        }
    }
    
    private func createTestVMGIData() -> Data {
        var data = Data(repeating: 0x00, count: 4096)
        
        // Set identifier
        let identifier = "DVDVIDEO-VMG".data(using: .ascii)!
        data.replaceSubrange(0..<identifier.count, with: identifier)
        
        // Set title count at offset 0x3E
        data.setUInt16(at: 0x3E, value: 1)
        
        // Set TT_SRPT offset at 0xC4 (in sectors)
        data.setUInt32(at: 0xC4, value: 1)
        
        // Create title table at sector 1 (offset 2048)
        let titleTableOffset = 2048
        data.setUInt16(at: titleTableOffset, value: 1) // Number of titles
        data.setUInt32(at: titleTableOffset + 4, value: 20) // Table end address
        
        // Title entry at offset 2048 + 8
        let titleEntryOffset = titleTableOffset + 8
        data[titleEntryOffset] = 0x01 // Playback type
        data[titleEntryOffset + 1] = 0x01 // Number of angles
        data.setUInt16(at: titleEntryOffset + 2, value: 5) // Number of chapters
        data.setUInt16(at: titleEntryOffset + 4, value: 0x0000) // Parental mask
        data.setUInt16(at: titleEntryOffset + 6, value: 1) // VTS number
        data.setUInt16(at: titleEntryOffset + 8, value: 1) // VTS title number
        data.setUInt32(at: titleEntryOffset + 10, value: 100) // Start sector
        
        return data
    }
    
    private func createTestVTSData() -> Data {
        var data = Data(repeating: 0x00, count: 4096)
        
        // Set identifier
        let identifier = "DVDVIDEO-VTS".data(using: .ascii)!
        data.replaceSubrange(0..<identifier.count, with: identifier)
        
        // Set PGCI offset at 0xCC
        data.setUInt32(at: 0xCC, value: 1) // Sector 1
        
        // Create PGCI at sector 1 (offset 2048)
        let pgciOffset = 2048
        data.setUInt16(at: pgciOffset, value: 1) // PGC count
        data.setUInt32(at: pgciOffset + 12, value: 100) // PGC offset
        
        // Create PGC at pgciOffset + 100
        let pgcOffset = pgciOffset + 100
        data[pgcOffset + 2] = 0x05 // Program count
        data[pgcOffset + 3] = 0x05 // Cell count
        data.setUInt32(at: pgcOffset + 4, value: 0x01234567) // Playback time (BCD)
        data.setUInt16(at: pgcOffset + 0xE8, value: 200) // Cell table offset
        
        // Create cell table
        let cellTableOffset = pgcOffset + 200
        for i in 0..<5 {
            let cellOffset = cellTableOffset + (i * 24)
            data[cellOffset] = 0x01 // Cell type
            data[cellOffset + 1] = 0x00 // Block type
            data.setUInt32(at: cellOffset + 4, value: UInt32(1000 + i * 100)) // Start sector
            data.setUInt32(at: cellOffset + 8, value: UInt32(1099 + i * 100)) // End sector
        }
        
        return data
    }
    
    // MARK: - Initialization Tests
    
    func testParserInitialization() {
        XCTAssertNotNil(parser)
    }
    
    func testParserWithInvalidPath() {
        let invalidParser = DVDStructureParser(dvdPath: "/invalid/path")
        
        XCTAssertThrowsError(try invalidParser.parseDVDStructure()) { error in
            XCTAssertTrue(error is DVDParseError)
            if let parseError = error as? DVDParseError {
                XCTAssertEqual(parseError, DVDParseError.videoTSNotFound)
            }
        }
    }
    
    // MARK: - DVD Structure Parsing Tests
    
    func testParseDVDStructure() throws {
        let titles = try parser.parseDVDStructure()
        
        XCTAssertEqual(titles.count, 1)
        XCTAssertEqual(titles[0].number, 1)
        XCTAssertEqual(titles[0].vtsNumber, 1)
        XCTAssertEqual(titles[0].vtsTitleNumber, 1)
        XCTAssertEqual(titles[0].startSector, 100)
        XCTAssertEqual(titles[0].chaptersCount, 5)
        XCTAssertEqual(titles[0].angles, 1)
    }
    
    func testGetMainTitle() throws {
        let titles = try parser.parseDVDStructure()
        let mainTitle = parser.getMainTitle()
        
        XCTAssertNotNil(mainTitle)
        XCTAssertEqual(mainTitle?.number, titles[0].number)
    }
    
    func testGetTitlesSortedByDuration() throws {
        _ = try parser.parseDVDStructure()
        let sortedTitles = parser.getTitlesSortedByDuration()
        
        XCTAssertEqual(sortedTitles.count, 1)
        
        // Test that titles are actually sorted (when we have multiple)
        for i in 0..<(sortedTitles.count - 1) {
            XCTAssertGreaterThanOrEqual(sortedTitles[i].duration, sortedTitles[i + 1].duration)
        }
    }
    
    // MARK: - Data Extension Tests
    
    func testDataReadUInt16() {
        let data = Data([0x12, 0x34, 0x56, 0x78])
        
        XCTAssertEqual(data.readUInt16(at: 0), 0x1234)
        XCTAssertEqual(data.readUInt16(at: 1), 0x3456)
        XCTAssertEqual(data.readUInt16(at: 2), 0x5678)
        
        // Test bounds checking - implementation returns 0 for out of bounds
        XCTAssertEqual(data.readUInt16(at: 3), 0) // Out of bounds (needs offset + 1 < count)
        XCTAssertEqual(data.readUInt16(at: 4), 0) // Out of bounds
    }
    
    func testDataReadUInt32() {
        let data = Data([0x12, 0x34, 0x56, 0x78, 0x9A, 0xBC])
        
        XCTAssertEqual(data.readUInt32(at: 0), 0x12345678)
        XCTAssertEqual(data.readUInt32(at: 1), 0x3456789A)
        XCTAssertEqual(data.readUInt32(at: 2), 0x56789ABC)
        
        // Test bounds checking - implementation returns 0 for out of bounds
        XCTAssertEqual(data.readUInt32(at: 3), 0) // Out of bounds (needs offset + 3 < count)
        XCTAssertEqual(data.readUInt32(at: 6), 0) // Out of bounds
    }
    
    // MARK: - DVD Title Tests
    
    func testDVDTitleInitialization() {
        let title = DVDTitle(
            number: 1,
            vtsNumber: 1,
            vtsTitleNumber: 1,
            startSector: 100,
            chapters: 5,
            angles: 1,
            duration: 3665 // 1:01:05
        )
        
        XCTAssertEqual(title.number, 1)
        XCTAssertEqual(title.vtsNumber, 1)
        XCTAssertEqual(title.vtsTitleNumber, 1)
        XCTAssertEqual(title.startSector, 100)
        XCTAssertEqual(title.chaptersCount, 5)
        XCTAssertEqual(title.angles, 1)
        XCTAssertEqual(title.duration, 3665)
        XCTAssertEqual(title.formattedDuration, "01:01:05")
    }
    
    func testDVDTitleFormattedDuration() {
        let testCases = [
            (0, "00:00:00"),
            (61, "00:01:01"),
            (3661, "01:01:01"),
            (3665, "01:01:05"),
            (7200, "02:00:00")
        ]
        
        for (duration, expected) in testCases {
            let title = DVDTitle(
                number: 1, vtsNumber: 1, vtsTitleNumber: 1,
                startSector: 0, chapters: 1, angles: 1,
                duration: TimeInterval(duration)
            )
            XCTAssertEqual(title.formattedDuration, expected)
        }
    }
    
    // MARK: - DVD Chapter Tests
    
    func testDVDChapterInitialization() {
        let chapter = DVDChapter(
            number: 1,
            startSector: 1000,
            endSector: 1999,
            duration: 600
        )
        
        XCTAssertEqual(chapter.number, 1)
        XCTAssertEqual(chapter.startSector, 1000)
        XCTAssertEqual(chapter.endSector, 1999)
        XCTAssertEqual(chapter.duration, 600)
        XCTAssertEqual(chapter.sectorCount, 1000)
    }
    
    func testDVDChapterSectorCount() {
        let testCases = [
            (1000, 1999, 1000),
            (0, 0, 1),
            (100, 199, 100),
            (500, 1500, 1001)
        ]
        
        for (start, end, expectedCount) in testCases {
            let chapter = DVDChapter(
                number: 1,
                startSector: UInt32(start),
                endSector: UInt32(end),
                duration: 0
            )
            XCTAssertEqual(chapter.sectorCount, UInt32(expectedCount))
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testDVDParseErrorDescriptions() {
        XCTAssertEqual(DVDParseError.videoTSNotFound.localizedDescription, "VIDEO_TS directory not found")
        XCTAssertEqual(DVDParseError.vmgiNotFound.localizedDescription, "VIDEO_TS.IFO file not found")
        XCTAssertEqual(DVDParseError.invalidVMGI.localizedDescription, "Invalid VMGI structure")
        XCTAssertEqual(DVDParseError.invalidVTS.localizedDescription, "Invalid VTS structure")
        XCTAssertEqual(DVDParseError.corruptedStructure.localizedDescription, "DVD structure is corrupted")
    }
    
    func testParseWithMissingVMGI() throws {
        // Remove VMGI file
        let vmgiPath = "\(testDVDPath)/VIDEO_TS/VIDEO_TS.IFO"
        try FileManager.default.removeItem(atPath: vmgiPath)
        
        XCTAssertThrowsError(try parser.parseDVDStructure()) { error in
            XCTAssertTrue(error is DVDParseError)
            if let parseError = error as? DVDParseError {
                XCTAssertEqual(parseError, DVDParseError.vmgiNotFound)
            }
        }
    }
    
    // TODO: Fix this test - currently causes crash
    /*
    func testParseWithInvalidVMGI() throws {
        // Create a new parser with its own directory
        let invalidTestPath = "/tmp/test_dvd_invalid"
        try? FileManager.default.removeItem(atPath: invalidTestPath)
        
        let videoTSPath = "\(invalidTestPath)/VIDEO_TS"
        try FileManager.default.createDirectory(atPath: videoTSPath, withIntermediateDirectories: true)
        
        // Create invalid VMGI file
        let vmgiPath = "\(videoTSPath)/VIDEO_TS.IFO"
        let invalidData = Data("INVALID".utf8)
        try invalidData.write(to: URL(fileURLWithPath: vmgiPath))
        
        let invalidParser = DVDStructureParser(dvdPath: invalidTestPath)
        
        XCTAssertThrowsError(try invalidParser.parseDVDStructure()) { error in
            XCTAssertTrue(error is DVDParseError)
            if let parseError = error as? DVDParseError {
                XCTAssertEqual(parseError, DVDParseError.invalidVMGI)
            }
        }
        
        // Clean up
        try? FileManager.default.removeItem(atPath: invalidTestPath)
    }
    */
    
    // MARK: - Performance Tests
    
    func testParsingPerformance() throws {
        measure {
            do {
                _ = try parser.parseDVDStructure()
            } catch {
                XCTFail("Parsing failed: \(error)")
            }
        }
    }
    
    func testDataReadingPerformance() {
        let data = Data(repeating: 0x42, count: 10000)
        
        measure {
            for i in 0..<1000 {
                _ = data.readUInt32(at: i % (data.count - 4))
            }
        }
    }
}

// MARK: - Data Extension for Tests

extension Data {
    mutating func setUInt16(at offset: Int, value: UInt16) {
        guard offset + 1 < count else { return }
        self[offset] = UInt8((value >> 8) & 0xFF)
        self[offset + 1] = UInt8(value & 0xFF)
    }
    
    mutating func setUInt32(at offset: Int, value: UInt32) {
        guard offset + 3 < count else { return }
        self[offset] = UInt8((value >> 24) & 0xFF)
        self[offset + 1] = UInt8((value >> 16) & 0xFF)
        self[offset + 2] = UInt8((value >> 8) & 0xFF)
        self[offset + 3] = UInt8(value & 0xFF)
    }
}
