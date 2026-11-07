import XCTest
@testable import AutoRip2MKV_Mac

/// Seamless-branching DVDs weave two versions' VOBUs together inside
/// interleaved cells; the reader follows each nav pack's NEXT_VOBU pointer.
final class DVDInterleavedNavigationTests: XCTestCase {

    /// A minimal nav pack: pack header, PCI and DSI packet headers, VOBU_EA
    /// and NEXT_VOBU filled in.
    private func navPack(lastSectorOffset: UInt32, nextVOBU: UInt32) -> Data {
        var d = Data(count: 2048)
        func put(_ bytes: [UInt8], _ o: Int) { for (i, b) in bytes.enumerated() { d[o + i] = b } }
        func put32(_ v: UInt32, _ o: Int) { put((0..<4).map { UInt8((v >> (24 - 8 * UInt32($0))) & 0xFF) }, o) }
        put([0x00, 0x00, 0x01, 0xBA], 0)
        put([0x00, 0x00, 0x01, 0xBF], 0x26); d[0x2C] = 0x00
        put([0x00, 0x00, 0x01, 0xBF], 0x400); d[0x406] = 0x01
        put32(lastSectorOffset, 0x407 + 8)
        put32(nextVOBU, 0x407 + 314)
        return d
    }

    func testReadsVOBUExtentAndNextPointer() {
        // Bit 31 set ("next VOBU has video") is masked off.
        let nav = MediaRipper.vobuNavigation(navPack: navPack(lastSectorOffset: 211, nextVOBU: 0x8000_0400))
        XCTAssertEqual(nav?.lastSectorOffset, 211)
        XCTAssertEqual(nav?.nextVOBUOffset, 0x400)
    }

    func testEndOfCell() {
        let nav = MediaRipper.vobuNavigation(navPack: navPack(lastSectorOffset: 90, nextVOBU: 0xBFFF_FFFF))
        XCTAssertEqual(nav?.lastSectorOffset, 90)
        XCTAssertNil(nav?.nextVOBUOffset)
    }

    func testRejectsNonNavSectors() {
        var video = navPack(lastSectorOffset: 1, nextVOBU: 2)
        video[0x406] = 0xE0                       // not a DSI substream
        XCTAssertNil(MediaRipper.vobuNavigation(navPack: video))
        XCTAssertNil(MediaRipper.vobuNavigation(navPack: Data(count: 2048)))
        XCTAssertNil(MediaRipper.vobuNavigation(navPack: Data([0x00, 0x00, 0x01, 0xBA])))
    }

    func testWorksOnDataSlices() {
        // Chunks read from the drive are slices of larger buffers.
        let buffer = Data(count: 2048) + navPack(lastSectorOffset: 7, nextVOBU: 8)
        XCTAssertEqual(MediaRipper.vobuNavigation(navPack: buffer.suffix(2048))?.nextVOBUOffset, 8)
    }

    func testInterleavedCellsAreKeptSeparateAndFlagged() {
        let layout = DVDStructureParser.cellLayout(ofCells: [
            (0x00, 0, 99),
            (0x00, 100, 199),     // merges with the previous plain cell
            (0x0C, 200, 999),     // seamless + interleaved
            (0x0C, 1000, 1999),   // interleaved, contiguous: still separate
            (0x00, 2000, 2099)    // plain after interleaved: not merged into it
        ])
        XCTAssertEqual(layout.ranges, [0...199, 200...999, 1000...1999, 2000...2099])
        XCTAssertEqual(layout.interleaved, [200...999, 1000...1999])
    }
}

/// Raw reads of branching titles carry ~4 s timestamp jumps that ffmpeg
/// closes only with a lower discontinuity threshold.
final class DVDBranchingEncodeArgumentsTests: XCTestCase {
    private let config = MediaRipper.RippingConfiguration(
        outputDirectory: "/tmp", selectedTitles: [], videoCodec: .h264, audioCodec: .aac,
        quality: .medium, includeSubtitles: true, includeChapters: true, mediaType: .dvd)

    private func title(interleaved: Bool) -> DVDTitle {
        let t = DVDTitle(number: 1, vtsNumber: 1, vtsTitleNumber: 1, startSector: 0,
                         chapters: 1, angles: 1, duration: 6830)
        t.cellRanges = [0...99, 100...999]
        if interleaved { t.interleavedRanges = [100...999] }
        return t
    }

    private func args(_ t: DVDTitle, raw: Bool) -> [String] {
        MediaRipper().dvdEncodeArguments(for: t, input: "in.vob", output: "out.mkv", configuration: config,
                                         ffmpegPath: "/opt/homebrew/bin/ffmpeg", labelLanguagesFromIFO: raw)
    }

    func testBranchingRawReadLowersThresholdBeforeInput() throws {
        let a = args(title(interleaved: true), raw: true)
        let threshold = try XCTUnwrap(a.firstIndex(of: "-dts_delta_threshold"))
        XCTAssertEqual(a[threshold + 1], "1")
        XCTAssertLessThan(threshold, try XCTUnwrap(a.firstIndex(of: "-i")))
    }

    func testOrdinaryTitlesAndMakeMKVInputUnchanged() {
        XCTAssertFalse(args(title(interleaved: false), raw: true).contains("-dts_delta_threshold"))
        XCTAssertFalse(args(title(interleaved: true), raw: false).contains("-dts_delta_threshold"))
    }
}
