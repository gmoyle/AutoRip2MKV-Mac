import XCTest
@testable import Spindle

/// DVD titles are staged by MakeMKV, which numbers titles its own way; the
/// app's chosen DVD titles have to be mapped onto MakeMKV's indices.
final class DVDMakeMKVMatchingTests: XCTestCase {

    private func dvd(_ number: Int, _ seconds: TimeInterval) -> DVDTitle {
        DVDTitle(number: number, vtsNumber: 1, vtsTitleNumber: number, startSector: 0,
                 chapters: 1, angles: 1, duration: seconds)
    }

    private func mk(_ index: Int, _ seconds: Int?, source: Int? = nil) -> MakeMKVBackend.Title {
        MakeMKVBackend.Title(index: index, durationSeconds: seconds, sizeBytes: nil, sourceTitle: source)
    }

    func testParsesTitlesFromInfoOutput() {
        let output = """
        MSG:1005,0,1,"MakeMKV started","%1 started","MakeMKV"
        TINFO:0,9,0,"1:53:50"
        TINFO:0,11,0,"6643123456"
        TINFO:0,24,0,"01"
        TINFO:1,9,0,"0:12:05"
        TINFO:1,11,0,"470000000"
        TINFO:1,24,0,"7"
        TINFO:2,9,0,"0:06:55"
        """
        XCTAssertEqual(MakeMKVBackend.parseTitles(fromInfoOutput: output), [
            mk(0, 6830, source: 1).withSize(6_643_123_456),
            mk(1, 725, source: 7).withSize(470_000_000),
            mk(2, 415)
        ])
    }

    func testMatchesBySourceTitleWhenReported() {
        // Same duration twice (two versions of the movie): the source title decides.
        let matches = MediaRipper.matchMakeMKVTitles(
            [dvd(2, 6830), dvd(1, 6830)],
            to: [mk(0, 6830, source: 1), mk(1, 6830, source: 2)])
        XCTAssertEqual(matches, [0: 1, 1: 0])
    }

    func testFallsBackToClosestDuration() {
        let matches = MediaRipper.matchMakeMKVTitles(
            [dvd(1, 6830), dvd(7, 725)],
            to: [mk(0, 723), mk(1, 6831), mk(2, 6900)])
        XCTAssertEqual(matches, [0: 1, 1: 0])
    }

    func testEachMakeMKVTitleUsedOnce() {
        let matches = MediaRipper.matchMakeMKVTitles(
            [dvd(1, 6830), dvd(2, 6830)],
            to: [mk(0, 6830)])
        XCTAssertEqual(matches, [0: 0])   // second DVD title falls back to libdvdcss
    }

    func testMatchesBranchingTitleShorterThanIFO() {
        // The Goonies: IFO 1:53:50, MakeMKV 1:53:16 (two identical versions).
        let matches = MediaRipper.matchMakeMKVTitles(
            [dvd(1, 6830)],
            to: [mk(0, 6796), mk(1, 6796), mk(2, 725)])
        XCTAssertEqual(matches, [0: 0])
    }

    func testNoMatchOutsideTolerance() {
        XCTAssertEqual(MediaRipper.matchMakeMKVTitles([dvd(1, 6830)], to: [mk(0, 6700), mk(1, nil)]), [:])
        XCTAssertEqual(MediaRipper.matchMakeMKVTitles([dvd(7, 120)], to: [mk(0, 116)]), [:])
    }
}

private extension MakeMKVBackend.Title {
    func withSize(_ bytes: Int64) -> MakeMKVBackend.Title {
        MakeMKVBackend.Title(index: index, durationSeconds: durationSeconds, sizeBytes: bytes, sourceTitle: sourceTitle)
    }
}

/// An expired MakeMKV beta refuses every command; the DVD path must surface
/// that as a licensing error instead of silently using the raw reader.
final class MakeMKVRegistrationDetectionTests: XCTestCase {
    func testExpiredBetaIsDetected() {
        let output = """
        MSG:1005,0,1,"MakeMKV v1.18.4 darwin(arm64-release) started","%1 started","MakeMKV v1.18.4"
        MSG:5021,131332,1,"This application version is too old.  Please download the latest version \
        at http://www.makemkv.com/ or enter a registration key to continue using the current version.",\
        "x","http://www.makemkv.com/"
        """
        XCTAssertTrue(MakeMKVBackend.registrationProblem(inRobotOutput: output)?
            .contains("version is too old") ?? false)
    }

    func testNormalOutputHasNoProblem() {
        let output = """
        MSG:1005,0,1,"MakeMKV v1.18.4 started","%1 started","MakeMKV"
        TINFO:0,9,0,"1:53:50"
        """
        XCTAssertNil(MakeMKVBackend.registrationProblem(inRobotOutput: output))
    }
}

final class MakeMKVOutdatedVersionTests: XCTestCase {
    func testDistinguishesExpiredBuildFromKeyProblem() {
        XCTAssertTrue(MakeMKVBackend.isOutdatedVersionMessage(
            "This application version is too old.  Please download the latest version"))
        XCTAssertFalse(MakeMKVBackend.isOutdatedVersionMessage("The evaluation period has expired."))
    }
}
