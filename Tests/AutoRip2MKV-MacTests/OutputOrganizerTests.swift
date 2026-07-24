import XCTest
@testable import AutoRip2MKV_Mac

/// Tests for OutputOrganizer — the choke point that turns the user's "Directory
/// Structure" setting into a rip's output folder. Replaces the old
/// SettingsUtilitiesTests (SettingsUtilities was never wired into the pipeline and
/// has been removed; see SETTINGS_AUDIT.md).
///
/// These exercise the pure `plannedDirectory` (no filesystem writes). They mutate
/// SettingsManager.shared (backed by UserDefaults.standard) and restore it, since
/// SettingsManager is a singleton with no injectable double.
final class OutputOrganizerTests: XCTestCase {

    private let settings = SettingsManager.shared
    private var savedStructure: Int = 1
    private var savedMovieFmt: String = ""
    private var savedTVFmt: String = ""

    override func setUp() {
        super.setUp()
        savedStructure = settings.outputStructureType
        savedMovieFmt = settings.movieDirectoryFormat
        savedTVFmt = settings.tvShowDirectoryFormat
    }

    override func tearDown() {
        settings.outputStructureType = savedStructure
        settings.movieDirectoryFormat = savedMovieFmt
        settings.tvShowDirectoryFormat = savedTVFmt
        super.tearDown()
    }

    private func plan(_ info: OutputOrganizer.RipInfo,
                      base: String = "/out", type: String = "Blu-ray") -> String {
        OutputOrganizer.plannedDirectory(
            baseDirectory: base, info: info, mediaTypeFolderName: type)
    }

    // MARK: - Title / year parsing

    func testParseTitleWithYear() {
        let info = OutputOrganizer.parse(displayName: "Hangmen (2017)", contentType: .movie)
        XCTAssertEqual(info.title, "Hangmen")
        XCTAssertEqual(info.year, 2017)
        XCTAssertEqual(info.plexName, "Hangmen (2017)")
    }

    func testParseTitleWithoutYear() {
        let info = OutputOrganizer.parse(displayName: "Firefly", contentType: .tvShow)
        XCTAssertEqual(info.title, "Firefly")
        XCTAssertNil(info.year)
        XCTAssertEqual(info.plexName, "Firefly")
    }

    func testParseIgnoresImplausibleParenNumber() {
        // "(3)" isn't a year — treat the whole thing as the title.
        let info = OutputOrganizer.parse(displayName: "Rocky (3)", contentType: .movie)
        XCTAssertEqual(info.title, "Rocky (3)")
        XCTAssertNil(info.year)
    }

    // MARK: - Structure: default (By Media Type) preserves legacy layout

    func testByMediaTypeUnknownUsesMediaTypeFolder() {
        settings.outputStructureType = 1
        let info = OutputOrganizer.parse(displayName: "Hangmen (2017)", contentType: .unknown)
        XCTAssertEqual(plan(info, type: "Blu-ray"), "/out/Blu-ray/Hangmen (2017)")
    }

    func testByMediaTypeMovieUsesMoviesFolder() {
        settings.outputStructureType = 1
        let info = OutputOrganizer.parse(displayName: "Hangmen (2017)", contentType: .movie)
        XCTAssertEqual(plan(info), "/out/Movies/Hangmen (2017)")
    }

    // MARK: - Structure: Flat

    func testFlatPutsTitleAtBase() {
        settings.outputStructureType = 0
        let info = OutputOrganizer.parse(displayName: "Hangmen (2017)", contentType: .movie)
        XCTAssertEqual(plan(info), "/out/Hangmen (2017)")
    }

    // MARK: - Structure: By Year

    func testByYearUsesYearFolder() {
        settings.outputStructureType = 2
        let info = OutputOrganizer.parse(displayName: "Hangmen (2017)", contentType: .movie)
        XCTAssertEqual(plan(info), "/out/2017/Hangmen (2017)")
    }

    func testByYearWithoutYearFallsBackToMediaType() {
        settings.outputStructureType = 2
        let info = OutputOrganizer.parse(displayName: "Some Disc", contentType: .movie)
        XCTAssertEqual(plan(info, type: "DVD"), "/out/DVD/Some Disc")
    }

    // MARK: - Structure: By Genre (no genre data → Unknown bucket)

    func testByGenreUsesUnknownBucket() {
        settings.outputStructureType = 3
        let info = OutputOrganizer.parse(displayName: "Hangmen (2017)", contentType: .movie)
        XCTAssertEqual(plan(info), "/out/Unknown/Hangmen (2017)")
    }

    // MARK: - Structure: Custom template

    func testCustomTemplateFillsKnownTokens() {
        settings.outputStructureType = 4
        settings.movieDirectoryFormat = "Movies/{title} ({year})"
        let info = OutputOrganizer.parse(displayName: "Hangmen (2017)", contentType: .movie)
        XCTAssertEqual(plan(info), "/out/Movies/Hangmen (2017)")
    }

    func testCustomTemplateDropsSegmentsWithUnknownTokens() {
        // {season} has no data → that path segment is dropped, not left literal.
        settings.outputStructureType = 4
        settings.tvShowDirectoryFormat = "TV Shows/{series}/Season {season}"
        let info = OutputOrganizer.parse(displayName: "Firefly", contentType: .tvShow)
        XCTAssertEqual(plan(info), "/out/TV Shows/Firefly")
    }

    func testCustomTemplateDropsYearWhenUnknown() {
        settings.outputStructureType = 4
        settings.movieDirectoryFormat = "Movies/{title} ({year})"
        let info = OutputOrganizer.parse(displayName: "Some Disc", contentType: .movie)
        // The "{title} ({year})" segment has an unfilled {year}, so it's dropped;
        // falls back to the plex leaf name so the rip still lands somewhere sane.
        XCTAssertEqual(plan(info), "/out/Movies/Some Disc")
    }

    func testCustomTemplateSanitizesPathHostileChars() {
        settings.outputStructureType = 4
        settings.movieDirectoryFormat = "Movies/{title}"
        let info = OutputOrganizer.parse(displayName: "A/B: C", contentType: .movie)
        XCTAssertEqual(plan(info), "/out/Movies/A-B- C")
    }
}
