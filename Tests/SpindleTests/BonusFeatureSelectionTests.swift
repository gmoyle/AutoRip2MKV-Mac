import XCTest
@testable import Spindle

/// "Rip bonus features" is off by default: a disc rips only its main movie.
final class BonusFeatureSelectionTests: XCTestCase {

    /// Titles shaped like The Goonies: the movie twice (two versions), three
    /// featurettes, and short intro clips.
    private func gooniesTitles() -> [DVDTitle] {
        let durations: [TimeInterval] = [6830, 6830, 29, 12, 32, 162, 725, 415, 410]
        return durations.enumerated().map { index, duration in
            DVDTitle(number: index + 1, vtsNumber: index < 6 ? 1 : 2, vtsTitleNumber: index < 6 ? index + 1 : index - 5,
                     startSector: 0, chapters: 1, angles: 1, duration: duration)
        }
    }

    func testMainFeatureOnlyWhenBonusFeaturesOff() {
        var rules = TitleAnalyzer.FilteringRules()
        rules.autoSelectMainFeature = true
        let picked = TitleAnalyzer().filterDVDTitles(gooniesTitles(), rules: rules)
        XCTAssertEqual(picked.count, 1)
        XCTAssertEqual(picked.first?.duration, 6830)
    }

    func testBonusFeaturesIncludedWhenOn() {
        var rules = TitleAnalyzer.FilteringRules()
        rules.autoSelectMainFeature = false
        let picked = TitleAnalyzer().filterDVDTitles(gooniesTitles(), rules: rules)
        XCTAssertGreaterThan(picked.count, 1)
        XCTAssertTrue(picked.contains { $0.duration == 725 })   // 12-minute featurette
        XCTAssertFalse(picked.contains { $0.duration < 60 })    // short clips still skipped
    }

    func testRipperHonorsConfigurationFlag() {
        let ripper = MediaRipper()
        let off = ripper.filterTitlesToRip(titles: gooniesTitles(), selectedTitles: [], ripBonusFeatures: false)
        let on = ripper.filterTitlesToRip(titles: gooniesTitles(), selectedTitles: [], ripBonusFeatures: true)
        XCTAssertEqual(off.count, 1)
        XCTAssertEqual(off.first?.duration, 6830)
        XCTAssertGreaterThan(on.count, 1)
    }

    func testExplicitSelectionIgnoresFlag() {
        let picked = MediaRipper().filterTitlesToRip(titles: gooniesTitles(), selectedTitles: [7, 8],
                                                     ripBonusFeatures: false)
        XCTAssertEqual(picked.map(\.number), [7, 8])
    }

    func testDefaultIsOff() {
        XCTAssertFalse(MediaRipper.RippingConfiguration(
            outputDirectory: "/tmp", selectedTitles: [], videoCodec: .h264, audioCodec: .aac,
            quality: .high, includeSubtitles: false, includeChapters: false, mediaType: .dvd).ripBonusFeatures)
    }

    func testFingerprintOnlyIncludesBonusFeaturesWhenOn() {
        func config(_ on: Bool) -> MediaRipper.RippingConfiguration {
            MediaRipper.RippingConfiguration(
                outputDirectory: "/tmp", selectedTitles: [], videoCodec: .h264, audioCodec: .aac,
                quality: .high, includeSubtitles: false, includeChapters: false, mediaType: .dvd,
                ripBonusFeatures: on)
        }
        // Off (the default) adds nothing, so existing rips aren't re-ripped.
        XCTAssertNil(ConversionQueue.settingsFingerprint(of: config(false))["ripBonusFeatures"])
        XCTAssertEqual(ConversionQueue.settingsFingerprint(of: config(true))["ripBonusFeatures"], "true")
    }
}
