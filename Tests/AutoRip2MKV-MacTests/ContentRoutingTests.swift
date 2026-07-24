import XCTest
@testable import AutoRip2MKV_Mac

/// Tests for movie-vs-TV classification, TINFO duration parsing, the pending
/// routing queue, and the atomic folder move.
final class ContentRoutingTests: XCTestCase {

    // MARK: - Classifier

    private func minutes(_ m: [Double]) -> [Int] { m.map { Int($0 * 60) } }

    func testClassifiesTVSeasonFromSimilarEpisodes() {
        // Six ~44-min episodes plus a couple of short extras = a TV season disc.
        let durations = minutes([44, 43, 45, 44, 46, 43, 2, 5])
        let result = ContentTypeClassifier.classify(titleDurationsSeconds: durations)
        XCTAssertEqual(result.type, .tvShow)
        XCTAssertGreaterThan(result.confidence, 0.6)
    }

    func testClassifiesHalfHourComedySeason() {
        // Thirteen ~22-min episodes = a half-hour comedy season.
        let durations = minutes(Array(repeating: 22, count: 13) + [3])
        let result = ContentTypeClassifier.classify(titleDurationsSeconds: durations)
        XCTAssertEqual(result.type, .tvShow)
    }

    func testClassifiesMovieFromSingleFeature() {
        // One 118-min feature plus short extras = a movie.
        let durations = minutes([118, 4, 2, 7, 3])
        let result = ContentTypeClassifier.classify(titleDurationsSeconds: durations)
        XCTAssertEqual(result.type, .movie)
        XCTAssertGreaterThan(result.confidence, 0.6)
    }

    func testClassifiesSingleTitleAsLowConfidenceMovie() {
        // Firefly disc actually ripped as one 138-min title — a single long
        // title with no cluster reads as a (low-confidence) movie, which is why
        // it belongs in the review queue rather than auto-routed.
        let durations = minutes([138])
        let result = ContentTypeClassifier.classify(titleDurationsSeconds: durations)
        XCTAssertEqual(result.type, .movie)
    }

    func testEmptyDurationsAreUnknown() {
        let result = ContentTypeClassifier.classify(titleDurationsSeconds: [])
        XCTAssertEqual(result.type, .unknown)
        XCTAssertEqual(result.confidence, 0)
    }

    func testTwoMediumTitlesAreAmbiguous() {
        // Two 50-min titles: not enough for a season, not a dominant feature.
        let durations = minutes([50, 48])
        let result = ContentTypeClassifier.classify(titleDurationsSeconds: durations)
        XCTAssertLessThan(result.confidence, ContentRouter.autoRouteConfidenceThreshold)
    }

    // MARK: - TINFO parsing

    func testParsesTitleDurationsFromInfoOutput() {
        let output = """
        MSG:1005,0,1,"MakeMKV started","%1 started","MakeMKV"
        TINFO:0,2,0,"Firefly Disc 1"
        TINFO:0,9,0,"0:44:15"
        TINFO:1,9,0,"0:43:50"
        TINFO:2,9,0,"1:58:03"
        TCOUNT:3
        """
        let durations = MakeMKVBackend.parseTitleDurations(fromInfoOutput: output)
        XCTAssertEqual(durations, [44 * 60 + 15, 43 * 60 + 50, 118 * 60 + 3])
    }

    func testParseHMSVariants() {
        XCTAssertEqual(MakeMKVBackend.parseHMS("1:02:03"), 3723)
        XCTAssertEqual(MakeMKVBackend.parseHMS("0:44:15"), 2655)
        XCTAssertEqual(MakeMKVBackend.parseHMS("44:15"), 2655)
        XCTAssertNil(MakeMKVBackend.parseHMS("not-a-time"))
    }

    func testParsingIgnoresNonDurationTINFO() {
        // Only id==9 rows are durations; id==2 (name) etc. must be ignored.
        let output = """
        TINFO:0,2,0,"Some Title"
        TINFO:0,27,0,"title_t00.mkv"
        TINFO:0,9,0,"0:22:00"
        """
        XCTAssertEqual(MakeMKVBackend.parseTitleDurations(fromInfoOutput: output), [22 * 60])
    }

    // MARK: - Pending routing queue

    private func makeQueue() -> PendingRoutingQueue {
        let suite = UserDefaults(suiteName: "routing-tests-\(UUID().uuidString)")!
        return PendingRoutingQueue(defaults: suite, key: "pending")
    }

    func testEnqueueAndRemove() {
        let q = makeQueue()
        let item = PendingRouting(discName: "DISC_1", folderPath: "/tmp/x",
                                  guessedType: .tvShow, confidence: 0.7)
        q.enqueue(item)
        XCTAssertEqual(q.count, 1)
        XCTAssertEqual(q.items.first?.discName, "DISC_1")
        q.remove(id: item.id)
        XCTAssertEqual(q.count, 0)
    }

    func testQueuePersistsAcrossInstances() {
        let suite = UserDefaults(suiteName: "routing-persist-\(UUID().uuidString)")!
        let q1 = PendingRoutingQueue(defaults: suite, key: "pending")
        q1.enqueue(PendingRouting(discName: "A", folderPath: "/tmp/a",
                                  guessedType: .movie, confidence: 0.9))
        let q2 = PendingRoutingQueue(defaults: suite, key: "pending")
        XCTAssertEqual(q2.count, 1)
        XCTAssertEqual(q2.items.first?.guessedType, .movie)
    }

    func testPruneMissingFolders() {
        let q = makeQueue()
        // A real temp folder that exists, and a bogus path that doesn't.
        let realDir = NSTemporaryDirectory().appending("prune-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(atPath: realDir, withIntermediateDirectories: true)
        q.enqueue(PendingRouting(discName: "real", folderPath: realDir,
                                 guessedType: .movie, confidence: 0.9))
        q.enqueue(PendingRouting(discName: "gone", folderPath: "/nope/missing",
                                 guessedType: .movie, confidence: 0.9))
        XCTAssertEqual(q.pruneMissingFolders(), 1)
        XCTAssertEqual(q.count, 1)
        XCTAssertEqual(q.items.first?.discName, "real")
    }

    // MARK: - Already-in-queue detection (skip re-rip while awaiting review)

    func testContainsDiscMatchesExactIdentity() {
        let q = makeQueue()
        q.enqueue(PendingRouting(discName: "FIREFLY", discIdentity: "FIREFLY#abc123",
                                 folderPath: "/tmp/x", guessedType: .tvShow, confidence: 0.7))
        XCTAssertTrue(q.containsDisc(identity: "FIREFLY#abc123"))
    }

    func testContainsDiscToleratesLabelDrift() {
        // Same disc remounted as "FIREFLY 1" keeps the fingerprint after "#".
        let q = makeQueue()
        q.enqueue(PendingRouting(discName: "FIREFLY", discIdentity: "FIREFLY#abc123",
                                 folderPath: "/tmp/x", guessedType: .tvShow, confidence: 0.7))
        XCTAssertTrue(q.containsDisc(identity: "FIREFLY 1#abc123"))
    }

    func testContainsDiscRejectsDifferentDisc() {
        let q = makeQueue()
        q.enqueue(PendingRouting(discName: "FIREFLY", discIdentity: "FIREFLY#abc123",
                                 folderPath: "/tmp/x", guessedType: .tvShow, confidence: 0.7))
        XCTAssertFalse(q.containsDisc(identity: "SERENITY#zzz999"))
    }

    func testContainsDiscFalseForLegacyEntryWithoutIdentity() {
        // Items persisted before discIdentity existed decode with a nil identity and
        // simply don't participate in matching (they still show in the review UI).
        let q = makeQueue()
        q.enqueue(PendingRouting(discName: "OLD", folderPath: "/tmp/x",
                                 guessedType: .movie, confidence: 0.9))
        XCTAssertFalse(q.containsDisc(identity: "OLD#abc123"))
    }

    // MARK: - Atomic move routing

    func testRouteMovesFolderToMoviesRoot() throws {
        let base = NSTemporaryDirectory().appending("route-\(UUID().uuidString)")
        let source = (base as NSString).appendingPathComponent("SOURCE/MOVIE_DISC")
        let moviesRoot = (base as NSString).appendingPathComponent("Movies")
        try FileManager.default.createDirectory(atPath: source, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: (source as NSString).appendingPathComponent("film.mkv"),
                                       contents: Data("x".utf8))

        // SettingsManager is a singleton on UserDefaults.standard; save and
        // restore the real value so the test doesn't mutate user settings.
        let settings = SettingsManager.shared
        let original = settings.moviesRootDirectory
        defer { settings.moviesRootDirectory = original }
        settings.moviesRootDirectory = moviesRoot

        let dest = try ContentRouter.route(folderPath: source, to: .movie, settings: settings)
        XCTAssertTrue(dest.hasPrefix(moviesRoot))
        XCTAssertTrue(FileManager.default.fileExists(atPath: (dest as NSString).appendingPathComponent("film.mkv")))
        XCTAssertFalse(FileManager.default.fileExists(atPath: source))
    }

    func testRouteToUnknownThrows() {
        XCTAssertThrowsError(try ContentRouter.route(folderPath: "/tmp/whatever", to: .unknown))
    }
}
