import XCTest
@testable import Spindle

/// A title set often holds several titles (movie + extras). Each title must be
/// read from its own cells, not the whole VOB set, or the extras get appended
/// to the movie (The Goonies came out 2h52m instead of 1h54m).
final class DVDCellRangeTests: XCTestCase {

    // MARK: - sectorRanges(ofCells:)

    func testContiguousCellsMerge() {
        let ranges = DVDStructureParser.sectorRanges(ofCells: [
            (0x00, 0, 99), (0x00, 100, 199), (0x00, 200, 299)
        ])
        XCTAssertEqual(ranges, [0...299])
    }

    func testGapsAndPlaybackOrderAreKept() {
        // A title that plays a later part of the VOB set first must not be sorted.
        let ranges = DVDStructureParser.sectorRanges(ofCells: [
            (0x00, 5000, 5999), (0x00, 0, 999), (0x00, 2000, 2999)
        ])
        XCTAssertEqual(ranges, [5000...5999, 0...999, 2000...2999])
    }

    func testOnlyFirstAngleOfAngleBlockIsRead() {
        // Category: block mode in bits 7–6 (1 first, 2 middle, 3 last),
        // block type in bits 5–4 (1 = angle).
        let ranges = DVDStructureParser.sectorRanges(ofCells: [
            (0x00, 0, 99),
            (0x50, 100, 199),   // first angle
            (0x90, 200, 299),   // second angle — skip
            (0xD0, 300, 399),   // last angle — skip
            (0x00, 400, 499)
        ])
        XCTAssertEqual(ranges, [0...199, 400...499])
    }

    func testMalformedCellsAreDropped() {
        XCTAssertEqual(DVDStructureParser.sectorRanges(ofCells: [(0x00, 500, 100), (0x00, 0, 9)]), [0...9])
    }

    // MARK: - pgcNumber(forVTSTitle:vtsi:)

    /// Minimal VTSI with a VTS_PTT_SRPT at sector 1 mapping VTS titles to PGCs.
    private func vtsi(pgcForTitle pgcs: [UInt16]) -> Data {
        var data = Data(count: 2048 * 2)
        func put32(_ v: UInt32, _ o: Int) { for i in 0..<4 { data[o + i] = UInt8((v >> (24 - 8 * UInt32(i))) & 0xFF) } }
        func put16(_ v: UInt16, _ o: Int) { data[o] = UInt8(v >> 8); data[o + 1] = UInt8(v & 0xFF) }
        put32(1, 0xC8)                                  // VTS_PTT_SRPT at sector 1
        let ptt = 2048
        put16(UInt16(pgcs.count), ptt)
        let entriesStart = 8 + pgcs.count * 4          // PTT entries follow the offset table
        for (i, pgc) in pgcs.enumerated() {
            let entry = entriesStart + i * 4
            put32(UInt32(entry), ptt + 8 + i * 4)
            put16(pgc, ptt + entry)                    // PGCN
            put16(1, ptt + entry + 2)                  // PGN
        }
        return data
    }

    func testPGCNumberComesFromPTTTable() {
        let data = vtsi(pgcForTitle: [3, 1, 2])
        XCTAssertEqual(DVDStructureParser.pgcNumber(forVTSTitle: 1, vtsi: data), 3)
        XCTAssertEqual(DVDStructureParser.pgcNumber(forVTSTitle: 3, vtsi: data), 2)
    }

    func testPGCNumberIsNilWhenUnavailable() {
        XCTAssertNil(DVDStructureParser.pgcNumber(forVTSTitle: 4, vtsi: vtsi(pgcForTitle: [1, 2])))
        XCTAssertNil(DVDStructureParser.pgcNumber(forVTSTitle: 1, vtsi: Data(count: 100)))
    }

    // MARK: - readRanges(of:)

    private func title(cells: [ClosedRange<UInt32>], vobBytes: Int?) throws -> DVDTitle {
        let t = DVDTitle(number: 1, vtsNumber: 1, vtsTitleNumber: 1, startSector: 0,
                         chapters: 1, angles: 1, duration: 60)
        t.cellRanges = cells
        if let vobBytes = vobBytes {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("VTS-\(UUID().uuidString).VOB")
            try Data(count: vobBytes).write(to: url)
            addTeardownBlock { try? FileManager.default.removeItem(at: url) }
            t.vobFiles = [url.path]
        }
        return t
    }

    func testReadsOnlyTheTitlesCells() throws {
        let t = try title(cells: [0...9, 20...29], vobBytes: 100 * 2048)
        XCTAssertEqual(MediaRipper().readRanges(of: t), [0...9, 20...29])
    }

    func testFallsBackToWholeVOBSetWhenCellsDontFit() throws {
        let t = try title(cells: [0...9, 90...150], vobBytes: 100 * 2048)
        XCTAssertEqual(MediaRipper().readRanges(of: t), [0...99])
    }

    func testFallsBackToWholeVOBSetWithoutCells() throws {
        let t = try title(cells: [], vobBytes: 50 * 2048)
        XCTAssertEqual(MediaRipper().readRanges(of: t), [0...49])
    }
}
