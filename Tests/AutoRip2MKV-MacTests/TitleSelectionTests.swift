// TitleSelectionTests.swift
// AutoRip2MKV-Mac
// Phase 2 Task 3: Intelligent Title Selection Tests
// Created: 2026-02-01

import XCTest
@testable import AutoRip2MKV_Mac

final class TitleSelectionTests: XCTestCase {
    
    var analyzer: TitleAnalyzer!
    
    override func setUp() {
        super.setUp()
        analyzer = TitleAnalyzer()
    }
    
    override func tearDown() {
        analyzer = nil
        super.tearDown()
    }
    
    // MARK: - DVD Title Analysis Tests
    
    func testDVDMainFeatureDetection() {
        // Create titles with main feature characteristics
        let mainTitle = DVDTitle(number: 1, vtsNumber: 1, vtsTitleNumber: 1, startSector: 0, chapters: 20, angles: 1, duration: 7200) // 2 hours, 20 chapters
        let bonusTitle = DVDTitle(number: 2, vtsNumber: 2, vtsTitleNumber: 1, startSector: 100000, chapters: 5, angles: 1, duration: 600) // 10 minutes
        
        let rules = TitleAnalyzer.FilteringRules()
        let scores = analyzer.analyzeDVDTitles([mainTitle, bonusTitle], rules: rules)
        
        XCTAssertEqual(scores.count, 2)
        XCTAssertEqual(scores[0].classification, .mainFeature, "First title should be classified as main feature")
        XCTAssertGreaterThan(scores[0].score, scores[1].score, "Main feature should have higher score")
    }
    
    func testDVDMenuDetection() {
        // Create very short title with minimal chapters
        let menuTitle = DVDTitle(number: 1, vtsNumber: 1, vtsTitleNumber: 1, startSector: 0, chapters: 1, angles: 1, duration: 30) // 30 seconds
        
        let rules = TitleAnalyzer.FilteringRules()
        let scores = analyzer.analyzeDVDTitles([menuTitle], rules: rules)
        
        XCTAssertEqual(scores.count, 1)
        XCTAssertEqual(scores[0].classification, .menu, "Very short title should be classified as menu")
    }
    
    func testDVDTrailerDetection() {
        // Create trailer-like title: 2-5 minutes, few chapters
        let trailerTitle = DVDTitle(number: 1, vtsNumber: 1, vtsTitleNumber: 1, startSector: 0, chapters: 2, angles: 1, duration: 180) // 3 minutes
        
        let rules = TitleAnalyzer.FilteringRules()
        let scores = analyzer.analyzeDVDTitles([trailerTitle], rules: rules)
        
        XCTAssertEqual(scores.count, 1)
        XCTAssertEqual(scores[0].classification, .trailer, "Short title with few chapters should be classified as trailer")
    }
    
    func testDVDDuplicateDetection() {
        // Create duplicate titles (same duration and chapters)
        let title1 = DVDTitle(number: 1, vtsNumber: 1, vtsTitleNumber: 1, startSector: 0, chapters: 15, angles: 1, duration: 6000) // 100 minutes
        let title2 = DVDTitle(number: 2, vtsNumber: 2, vtsTitleNumber: 1, startSector: 50000, chapters: 15, angles: 1, duration: 6002) // 100 minutes, 2s difference
        
        let rules = TitleAnalyzer.FilteringRules()
        let scores = analyzer.analyzeDVDTitles([title1, title2], rules: rules)
        
        XCTAssertEqual(scores.count, 2)
        
        // One should be marked as duplicate
        let duplicates = scores.filter { $0.classification == .duplicate }
        XCTAssertEqual(duplicates.count, 1, "One title should be marked as duplicate")
    }
    
    func testDVDBonusFeatureClassification() {
        // Bonus feature: 5-60 minutes, moderate structure
        let bonusTitle = DVDTitle(number: 1, vtsNumber: 1, vtsTitleNumber: 1, startSector: 0, chapters: 8, angles: 1, duration: 1800) // 30 minutes
        
        let rules = TitleAnalyzer.FilteringRules()
        let scores = analyzer.analyzeDVDTitles([bonusTitle], rules: rules)
        
        XCTAssertEqual(scores.count, 1)
        XCTAssertEqual(scores[0].classification, .bonusFeature, "30-minute title should be classified as bonus feature")
    }
    
    func testDVDExtendedEditionDetection() {
        // Create main feature and slightly longer extended edition
        let theatrical = DVDTitle(number: 1, vtsNumber: 1, vtsTitleNumber: 1, startSector: 0, chapters: 18, angles: 1, duration: 7200) // 2 hours
        let extended = DVDTitle(number: 2, vtsNumber: 2, vtsTitleNumber: 1, startSector: 100000, chapters: 20, angles: 1, duration: 7800) // 2h10m (8% longer)
        
        let rules = TitleAnalyzer.FilteringRules()
        let scores = analyzer.analyzeDVDTitles([theatrical, extended], rules: rules)
        
        XCTAssertEqual(scores.count, 2)
        
        // Both should be feature-length, extended should score higher or be classified differently
        let mainFeatures = scores.filter { $0.classification == .mainFeature || $0.classification == .extendedEdition }
        XCTAssertEqual(mainFeatures.count, 2, "Both titles should be classified as feature-length")
    }
    
    // MARK: - DVD Filtering Tests
    
    func testDVDFilterMenus() {
        let mainTitle = DVDTitle(number: 1, vtsNumber: 1, vtsTitleNumber: 1, startSector: 0, chapters: 20, angles: 1, duration: 7200)
        let menuTitle = DVDTitle(number: 2, vtsNumber: 2, vtsTitleNumber: 1, startSector: 50000, chapters: 1, angles: 1, duration: 30)
        
        var rules = TitleAnalyzer.FilteringRules()
        rules.skipMenus = true
        let filtered = analyzer.filterDVDTitles([mainTitle, menuTitle], rules: rules)
        
        XCTAssertEqual(filtered.count, 1, "Menu should be filtered out")
        XCTAssertEqual(filtered[0].number, 1, "Only main title should remain")
    }
    
    func testDVDFilterTrailers() {
        let mainTitle = DVDTitle(number: 1, vtsNumber: 1, vtsTitleNumber: 1, startSector: 0, chapters: 20, angles: 1, duration: 7200)
        let trailerTitle = DVDTitle(number: 2, vtsNumber: 2, vtsTitleNumber: 1, startSector: 50000, chapters: 2, angles: 1, duration: 180)
        
        var rules = TitleAnalyzer.FilteringRules()
        rules.skipTrailers = true
        let filtered = analyzer.filterDVDTitles([mainTitle, trailerTitle], rules: rules)
        
        XCTAssertEqual(filtered.count, 1, "Trailer should be filtered out")
        XCTAssertEqual(filtered[0].number, 1, "Only main title should remain")
    }
    
    func testDVDFilterDuplicates() {
        let title1 = DVDTitle(number: 1, vtsNumber: 1, vtsTitleNumber: 1, startSector: 0, chapters: 15, angles: 1, duration: 6000)
        let title2 = DVDTitle(number: 2, vtsNumber: 2, vtsTitleNumber: 1, startSector: 50000, chapters: 15, angles: 1, duration: 6001) // 1s difference
        
        var rules = TitleAnalyzer.FilteringRules()
        rules.skipDuplicates = true
        let filtered = analyzer.filterDVDTitles([title1, title2], rules: rules)
        
        XCTAssertEqual(filtered.count, 1, "Duplicate should be filtered out")
    }
    
    func testDVDAutoSelectMainFeature() {
        let mainTitle = DVDTitle(number: 1, vtsNumber: 1, vtsTitleNumber: 1, startSector: 0, chapters: 20, angles: 1, duration: 7200)
        let bonusTitle = DVDTitle(number: 2, vtsNumber: 2, vtsTitleNumber: 1, startSector: 50000, chapters: 8, angles: 1, duration: 1800)
        
        var rules = TitleAnalyzer.FilteringRules()
        rules.autoSelectMainFeature = true
        let filtered = analyzer.filterDVDTitles([mainTitle, bonusTitle], rules: rules)
        
        XCTAssertEqual(filtered.count, 1, "Should auto-select only main feature")
        XCTAssertEqual(filtered[0].number, 1, "Main feature should be selected")
    }
    
    func testDVDPreferLongestTitle() {
        let theatrical = DVDTitle(number: 1, vtsNumber: 1, vtsTitleNumber: 1, startSector: 0, chapters: 18, angles: 1, duration: 7200)
        let extended = DVDTitle(number: 2, vtsNumber: 2, vtsTitleNumber: 1, startSector: 50000, chapters: 20, angles: 1, duration: 7800)
        
        var rules = TitleAnalyzer.FilteringRules()
        rules.autoSelectMainFeature = true
        rules.preferLongestTitle = true
        let filtered = analyzer.filterDVDTitles([theatrical, extended], rules: rules)
        
        XCTAssertEqual(filtered.count, 1, "Should select one main feature")
        XCTAssertEqual(filtered[0].duration, 7800, "Should prefer longest title")
    }
    
    func testDVDMinimumDurationThresholds() {
        let featureTitle = DVDTitle(number: 1, vtsNumber: 1, vtsTitleNumber: 1, startSector: 0, chapters: 20, angles: 1, duration: 3700) // 61:40
        let bonusTitle = DVDTitle(number: 2, vtsNumber: 2, vtsTitleNumber: 1, startSector: 50000, chapters: 5, angles: 1, duration: 200) // 3:20
        
        var rules = TitleAnalyzer.FilteringRules()
        rules.minMainFeatureDuration = 3600 // 60 minutes
        rules.minBonusFeatureDuration = 300 // 5 minutes
        let filtered = analyzer.filterDVDTitles([featureTitle, bonusTitle], rules: rules)
        
        XCTAssertEqual(filtered.count, 1, "Short bonus below threshold should be filtered")
        XCTAssertEqual(filtered[0].number, 1, "Feature meeting threshold should remain")
    }
    
    // MARK: - Blu-ray Playlist Analysis Tests
    
    func testBluRayMainFeatureDetection() {
        let mainPlaylist = BluRayPlaylist(number: 800, filename: "00800.mpls")
        mainPlaylist.duration = 7200
        mainPlaylist.marks = (0..<20).map { BluRayMark(index: $0, type: 1, playItemRef: 0, time: UInt32($0 * 360)) }
        
        let bonusPlaylist = BluRayPlaylist(number: 801, filename: "00801.mpls")
        bonusPlaylist.duration = 600
        bonusPlaylist.marks = (0..<5).map { BluRayMark(index: $0, type: 1, playItemRef: 0, time: UInt32($0 * 120)) }
        
        let rules = TitleAnalyzer.FilteringRules()
        let scores = analyzer.analyzeBluRayPlaylists([mainPlaylist, bonusPlaylist], rules: rules)
        
        XCTAssertEqual(scores.count, 2)
        XCTAssertEqual(scores[0].classification, .mainFeature, "Main playlist should be classified as main feature")
        XCTAssertGreaterThan(scores[0].score, scores[1].score, "Main feature should score higher")
    }
    
    func testBluRayMenuDetection() {
        let menuPlaylist = BluRayPlaylist(number: 1, filename: "00001.mpls")
        menuPlaylist.duration = 45
        menuPlaylist.marks = [BluRayMark(index: 0, type: 0, playItemRef: 0, time: 0)]
        
        let rules = TitleAnalyzer.FilteringRules()
        let scores = analyzer.analyzeBluRayPlaylists([menuPlaylist], rules: rules)
        
        XCTAssertEqual(scores.count, 1)
        XCTAssertEqual(scores[0].classification, .menu, "Very short playlist should be classified as menu")
    }
    
    func testBluRayDuplicateDetection() {
        let playlist1 = BluRayPlaylist(number: 800, filename: "00800.mpls")
        playlist1.duration = 6000
        playlist1.marks = (0..<15).map { BluRayMark(index: $0, type: 1, playItemRef: 0, time: UInt32($0 * 400)) }
        
        let playlist2 = BluRayPlaylist(number: 801, filename: "00801.mpls")
        playlist2.duration = 6003 // 3s difference
        playlist2.marks = (0..<15).map { BluRayMark(index: $0, type: 1, playItemRef: 0, time: UInt32($0 * 400)) }
        
        let rules = TitleAnalyzer.FilteringRules()
        let scores = analyzer.analyzeBluRayPlaylists([playlist1, playlist2], rules: rules)
        
        XCTAssertEqual(scores.count, 2)
        
        let duplicates = scores.filter { $0.classification == .duplicate }
        XCTAssertEqual(duplicates.count, 1, "One playlist should be marked as duplicate")
    }
    
    func testBluRayComplexStructureScoring() {
        // Complex multi-clip playlist (seamless branching)
        let complexPlaylist = BluRayPlaylist(number: 800, filename: "00800.mpls")
        complexPlaylist.duration = 7200
        complexPlaylist.playItems = (0..<12).map { 
            BluRayPlayItem(index: $0, clipName: "0\($0)000", codecID: "H264", inTime: 0, outTime: 600, duration: 600, angleCount: 1)
        }
        complexPlaylist.marks = (0..<18).map { BluRayMark(index: $0, type: 1, playItemRef: 0, time: UInt32($0 * 400)) }
        
        let rules = TitleAnalyzer.FilteringRules()
        let scores = analyzer.analyzeBluRayPlaylists([complexPlaylist], rules: rules)
        
        XCTAssertEqual(scores.count, 1)
        XCTAssertEqual(scores[0].classification, .mainFeature)
        XCTAssertGreaterThan(scores[0].score, 0.7, "Complex main feature should score highly")
    }
    
    // MARK: - Blu-ray Filtering Tests
    
    func testBluRayFilterMenus() {
        let mainPlaylist = BluRayPlaylist(number: 800, filename: "00800.mpls")
        mainPlaylist.duration = 7200
        mainPlaylist.marks = (0..<20).map { BluRayMark(index: $0, type: 1, playItemRef: 0, time: UInt32($0 * 360)) }
        
        let menuPlaylist = BluRayPlaylist(number: 1, filename: "00001.mpls")
        menuPlaylist.duration = 30
        menuPlaylist.marks = []
        
        var rules = TitleAnalyzer.FilteringRules()
        rules.skipMenus = true
        let filtered = analyzer.filterBluRayPlaylists([mainPlaylist, menuPlaylist], rules: rules)
        
        XCTAssertEqual(filtered.count, 1, "Menu should be filtered out")
        XCTAssertEqual(filtered[0].number, 800, "Only main playlist should remain")
    }
    
    func testBluRayAutoSelectMainFeature() {
        let mainPlaylist = BluRayPlaylist(number: 800, filename: "00800.mpls")
        mainPlaylist.duration = 7200
        mainPlaylist.marks = (0..<20).map { BluRayMark(index: $0, type: 1, playItemRef: 0, time: UInt32($0 * 360)) }
        
        let bonusPlaylist = BluRayPlaylist(number: 801, filename: "00801.mpls")
        bonusPlaylist.duration = 1800
        bonusPlaylist.marks = (0..<8).map { BluRayMark(index: $0, type: 1, playItemRef: 0, time: UInt32($0 * 225)) }
        
        var rules = TitleAnalyzer.FilteringRules()
        rules.autoSelectMainFeature = true
        let filtered = analyzer.filterBluRayPlaylists([mainPlaylist, bonusPlaylist], rules: rules)
        
        XCTAssertEqual(filtered.count, 1, "Should auto-select only main feature")
        XCTAssertEqual(filtered[0].number, 800, "Main playlist should be selected")
    }
    
    // MARK: - Settings Integration Tests
    
    func testSettingsManagerDefaults() {
        // Clear settings
        UserDefaults.standard.removeObject(forKey: "intelligentTitleSelection")
        UserDefaults.standard.removeObject(forKey: "skipMenus")
        UserDefaults.standard.removeObject(forKey: "skipTrailers")
        UserDefaults.standard.removeObject(forKey: "skipDuplicates")
        UserDefaults.standard.removeObject(forKey: "autoSelectMainFeature")
        UserDefaults.standard.removeObject(forKey: "preferLongestTitle")
        UserDefaults.standard.removeObject(forKey: "minMainFeatureDuration")
        UserDefaults.standard.removeObject(forKey: "minBonusFeatureDuration")
        
        SettingsManager.shared.setDefaultsIfNeeded()
        
        XCTAssertTrue(SettingsManager.shared.intelligentTitleSelection, "Intelligent selection should be enabled by default")
        XCTAssertTrue(SettingsManager.shared.skipMenus, "Skip menus should be enabled by default")
        XCTAssertTrue(SettingsManager.shared.skipTrailers, "Skip trailers should be enabled by default")
        XCTAssertTrue(SettingsManager.shared.skipDuplicates, "Skip duplicates should be enabled by default")
        XCTAssertFalse(SettingsManager.shared.autoSelectMainFeature, "Auto-select should be disabled by default")
        XCTAssertTrue(SettingsManager.shared.preferLongestTitle, "Prefer longest should be enabled by default")
        XCTAssertEqual(SettingsManager.shared.minMainFeatureDuration, 3600, "Default main feature minimum should be 60 minutes")
        XCTAssertEqual(SettingsManager.shared.minBonusFeatureDuration, 300, "Default bonus minimum should be 5 minutes")
    }
    
    func testSettingsToFilteringRules() {
        SettingsManager.shared.intelligentTitleSelection = true
        SettingsManager.shared.skipMenus = true
        SettingsManager.shared.skipTrailers = false
        SettingsManager.shared.skipDuplicates = true
        SettingsManager.shared.autoSelectMainFeature = true
        SettingsManager.shared.preferLongestTitle = false
        SettingsManager.shared.minMainFeatureDuration = 4800 // 80 minutes
        SettingsManager.shared.minBonusFeatureDuration = 600 // 10 minutes
        
        let rules = SettingsManager.shared.getTitleFilteringRules()
        
        XCTAssertTrue(rules.skipMenus)
        XCTAssertFalse(rules.skipTrailers)
        XCTAssertTrue(rules.skipDuplicates)
        XCTAssertTrue(rules.autoSelectMainFeature)
        XCTAssertFalse(rules.preferLongestTitle)
        XCTAssertEqual(rules.minMainFeatureDuration, 4800)
        XCTAssertEqual(rules.minBonusFeatureDuration, 600)
    }
    
    func testIntelligentSelectionDisabled() {
        SettingsManager.shared.intelligentTitleSelection = false
        
        let rules = SettingsManager.shared.getTitleFilteringRules()
        
        XCTAssertFalse(rules.skipMenus, "Filtering should be disabled when intelligent selection is off")
        XCTAssertFalse(rules.skipTrailers)
        XCTAssertFalse(rules.skipDuplicates)
        XCTAssertFalse(rules.autoSelectMainFeature)
    }
    
    // MARK: - Edge Cases
    
    func testEmptyTitleList() {
        let rules = TitleAnalyzer.FilteringRules()
        let scores = analyzer.analyzeDVDTitles([], rules: rules)
        
        XCTAssertEqual(scores.count, 0, "Empty input should return empty results")
    }
    
    func testSingleTitle() {
        let singleTitle = DVDTitle(number: 1, vtsNumber: 1, vtsTitleNumber: 1, startSector: 0, chapters: 15, angles: 1, duration: 5400)
        
        let rules = TitleAnalyzer.FilteringRules()
        let scores = analyzer.analyzeDVDTitles([singleTitle], rules: rules)
        
        XCTAssertEqual(scores.count, 1)
        XCTAssertEqual(scores[0].classification, .mainFeature, "Single feature-length title should be main feature")
    }
    
    func testMultipleMainFeatures() {
        // Some discs have multiple feature-length content (double features, etc.)
        let feature1 = DVDTitle(number: 1, vtsNumber: 1, vtsTitleNumber: 1, startSector: 0, chapters: 15, angles: 1, duration: 5400)
        let feature2 = DVDTitle(number: 2, vtsNumber: 2, vtsTitleNumber: 1, startSector: 50000, chapters: 18, angles: 1, duration: 6000)
        
        var rules = TitleAnalyzer.FilteringRules()
        rules.autoSelectMainFeature = false // Don't auto-select
        let filtered = analyzer.filterDVDTitles([feature1, feature2], rules: rules)
        
        XCTAssertEqual(filtered.count, 2, "Both features should be retained when not auto-selecting")
    }
    
    func testVeryShortTitles() {
        // DVD warnings, FBI screens, etc.
        let warning = DVDTitle(number: 1, vtsNumber: 1, vtsTitleNumber: 1, startSector: 0, chapters: 1, angles: 1, duration: 5)
        
        let rules = TitleAnalyzer.FilteringRules()
        let scores = analyzer.analyzeDVDTitles([warning], rules: rules)
        
        XCTAssertEqual(scores.count, 1)
        XCTAssertEqual(scores[0].classification, .menu, "Very short content should be classified as menu")
    }
    
    func testZeroDuration() {
        let zeroTitle = DVDTitle(number: 1, vtsNumber: 1, vtsTitleNumber: 1, startSector: 0, chapters: 0, angles: 1, duration: 0)
        
        let rules = TitleAnalyzer.FilteringRules()
        let scores = analyzer.analyzeDVDTitles([zeroTitle], rules: rules)
        
        XCTAssertEqual(scores.count, 1)
        XCTAssertEqual(scores[0].classification, .menu, "Zero duration should be classified as menu")
    }
    
    func testHighAngleCount() {
        // Multi-angle main feature
        let multiAngle = DVDTitle(number: 1, vtsNumber: 1, vtsTitleNumber: 1, startSector: 0, chapters: 20, angles: 4, duration: 7200)
        
        let rules = TitleAnalyzer.FilteringRules()
        let scores = analyzer.analyzeDVDTitles([multiAngle], rules: rules)
        
        XCTAssertEqual(scores.count, 1)
        XCTAssertEqual(scores[0].classification, .mainFeature, "Multi-angle feature should be classified as main")
        XCTAssertGreaterThan(scores[0].score, 0.8, "Multi-angle feature should score highly")
    }
}
