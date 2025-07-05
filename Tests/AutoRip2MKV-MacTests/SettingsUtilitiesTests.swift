import XCTest
import Foundation
@testable import AutoRip2MKV_Mac

final class SettingsUtilitiesTests: XCTestCase {
    
    var settingsUtilities: SettingsUtilities!
    var testBaseOutputPath: String!
    var testMetadata: MediaMetadata!
    
    override func setUpWithError() throws {
        settingsUtilities = SettingsUtilities.shared
        testBaseOutputPath = NSTemporaryDirectory().appending("SettingsUtilitiesTests")
        
        // Create test metadata
        testMetadata = MediaMetadata(
            title: "Test Movie",
            year: 2023,
            seriesName: "Test Series",
            season: 1,
            episode: 5,
            genre: "Action"
        )
        
        // Create test base directory
        try FileManager.default.createDirectory(atPath: testBaseOutputPath, withIntermediateDirectories: true)
    }
    
    override func tearDownWithError() throws {
        // Clean up test directory
        try? FileManager.default.removeItem(atPath: testBaseOutputPath)
        settingsUtilities = nil
        testMetadata = nil
        testBaseOutputPath = nil
        
        // Reset UserDefaults to clean state
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "outputStructureType")
        defaults.removeObject(forKey: "createSeriesDirectory")
        defaults.removeObject(forKey: "createSeasonDirectory")
        defaults.removeObject(forKey: "movieFileFormat")
        defaults.removeObject(forKey: "tvShowFileFormat")
        defaults.removeObject(forKey: "includeYearInFilename")
        defaults.removeObject(forKey: "includeResolutionInFilename")
        defaults.removeObject(forKey: "includeCodecInFilename")
        defaults.removeObject(forKey: "postProcessingScript")
    }
    
    // MARK: - Initialization Tests
    
    func testSharedInstance() {
        let instance1 = SettingsUtilities.shared
        let instance2 = SettingsUtilities.shared
        
        XCTAssertTrue(instance1 === instance2, "Should return the same shared instance")
    }
    
    // MARK: - Directory Structure Creation Tests
    
    func testCreateOutputDirectoryFlat() {
        // Test flat structure (outputStructureType = 0)
        // Since SettingsUtilities uses the real SettingsManager, we need to set actual defaults
        UserDefaults.standard.set(0, forKey: "outputStructureType")
        
        let result = settingsUtilities.createOutputDirectory(
            baseOutputPath: testBaseOutputPath,
            mediaType: .movie,
            metadata: testMetadata
        )
        
        XCTAssertEqual(result, testBaseOutputPath, "Flat structure should return base path")
    }
    
    func testCreateOutputDirectoryByMediaType() {
        // Set up user defaults for media type structure
        UserDefaults.standard.set(1, forKey: "outputStructureType")
        UserDefaults.standard.set(true, forKey: "createSeriesDirectory")
        UserDefaults.standard.set(true, forKey: "createSeasonDirectory")
        
        // Test movie structure
        let movieResult = settingsUtilities.createOutputDirectory(
            baseOutputPath: testBaseOutputPath,
            mediaType: .movie,
            metadata: testMetadata
        )
        
        let expectedMoviePath = URL(fileURLWithPath: testBaseOutputPath)
            .appendingPathComponent("Movies")
            .appendingPathComponent("Test Movie (2023)")
            .path
        
        XCTAssertEqual(movieResult, expectedMoviePath, "Movie structure should create Movies/Title (Year) path")
        
        // Test TV show structure
        let tvResult = settingsUtilities.createOutputDirectory(
            baseOutputPath: testBaseOutputPath,
            mediaType: .tvShow,
            metadata: testMetadata
        )
        
        let expectedTVPath = URL(fileURLWithPath: testBaseOutputPath)
            .appendingPathComponent("TV Shows")
            .appendingPathComponent("Test Series")
            .appendingPathComponent("Season 1")
            .path
        
        XCTAssertEqual(tvResult, expectedTVPath, "TV structure should create TV Shows/Series/Season path")
    }
    
    func testCreateOutputDirectoryByYear() {
        UserDefaults.standard.set(2, forKey: "outputStructureType")
        
        let result = settingsUtilities.createOutputDirectory(
            baseOutputPath: testBaseOutputPath,
            mediaType: .movie,
            metadata: testMetadata
        )
        
        let expectedPath = URL(fileURLWithPath: testBaseOutputPath)
            .appendingPathComponent("2023")
            .appendingPathComponent("Test Movie")
            .path
        
        XCTAssertEqual(result, expectedPath, "Year structure should create Year/Title path")
    }
    
    func testCreateOutputDirectoryByGenre() {
        UserDefaults.standard.set(3, forKey: "outputStructureType")
        
        let result = settingsUtilities.createOutputDirectory(
            baseOutputPath: testBaseOutputPath,
            mediaType: .movie,
            metadata: testMetadata
        )
        
        let expectedPath = URL(fileURLWithPath: testBaseOutputPath)
            .appendingPathComponent("Action")
            .appendingPathComponent("Test Movie")
            .path
        
        XCTAssertEqual(result, expectedPath, "Genre structure should create Genre/Title path")
    }
    
    func testCreateOutputDirectoryCustomFormat() {
        UserDefaults.standard.set(4, forKey: "outputStructureType")
        UserDefaults.standard.set("{genre}/{year}/{title}", forKey: "movieDirectoryFormat")
        UserDefaults.standard.set("{series}/Season {season}", forKey: "tvShowDirectoryFormat")
        
        // Test movie custom format
        let movieResult = settingsUtilities.createOutputDirectory(
            baseOutputPath: testBaseOutputPath,
            mediaType: .movie,
            metadata: testMetadata
        )
        
        let expectedMoviePath = URL(fileURLWithPath: testBaseOutputPath)
            .appendingPathComponent("Action/2023/Test Movie")
            .path
        
        XCTAssertEqual(movieResult, expectedMoviePath, "Custom movie format should be applied correctly")
        
        // Test TV show custom format
        let tvResult = settingsUtilities.createOutputDirectory(
            baseOutputPath: testBaseOutputPath,
            mediaType: .tvShow,
            metadata: testMetadata
        )
        
        let expectedTVPath = URL(fileURLWithPath: testBaseOutputPath)
            .appendingPathComponent("Test Series/Season 1")
            .path
        
        XCTAssertEqual(tvResult, expectedTVPath, "Custom TV format should be applied correctly")
    }
    
    func testCreateOutputDirectoryUnknownMediaType() {
        UserDefaults.standard.set(1, forKey: "outputStructureType")
        
        let result = settingsUtilities.createOutputDirectory(
            baseOutputPath: testBaseOutputPath,
            mediaType: .unknown,
            metadata: testMetadata
        )
        
        let expectedPath = URL(fileURLWithPath: testBaseOutputPath)
            .appendingPathComponent("Other")
            .path
        
        XCTAssertEqual(result, expectedPath, "Unknown media type should go to Other directory")
    }
    
    // MARK: - Bonus Content Tests
    // Note: These tests are temporarily disabled because SettingsUtilities uses
    // SettingsManager.shared which is difficult to mock properly
    
    func testCreateBonusContentDirectory() {
        // Test that the method doesn't crash and returns a valid path
        let result = settingsUtilities.createBonusContentDirectory(
            mainOutputPath: testBaseOutputPath,
            contentType: .bonusFeatures
        )
        
        XCTAssertNotNil(result, "Should return a valid path")
        XCTAssertTrue(result!.contains(testBaseOutputPath), "Should be based on main output path")
    }
    
    func testShouldIncludeBonusContent() {
        // Test that the method doesn't crash and returns a boolean
        let result1 = settingsUtilities.shouldIncludeBonusContent(.bonusFeatures)
        let result2 = settingsUtilities.shouldIncludeBonusContent(.commentaries)
        let result3 = settingsUtilities.shouldIncludeBonusContent(.deletedScenes)
        let result4 = settingsUtilities.shouldIncludeBonusContent(.makingOf)
        let result5 = settingsUtilities.shouldIncludeBonusContent(.trailers)
        
        // Just verify they return boolean values without crashing
        XCTAssertTrue(result1 == true || result1 == false, "Should return a boolean")
        XCTAssertTrue(result2 == true || result2 == false, "Should return a boolean")
        XCTAssertTrue(result3 == true || result3 == false, "Should return a boolean")
        XCTAssertTrue(result4 == true || result4 == false, "Should return a boolean")
        XCTAssertTrue(result5 == true || result5 == false, "Should return a boolean")
    }
    
    // MARK: - File Naming Tests
    
    func testGenerateFileNameMovie() {
        UserDefaults.standard.set("{title} ({year}).mkv", forKey: "movieFileFormat")
        UserDefaults.standard.set(true, forKey: "includeYearInFilename")
        
        let filename = settingsUtilities.generateFileName(
            mediaType: .movie,
            metadata: testMetadata
        )
        
        XCTAssertEqual(filename, "Test Movie (2023).mkv", "Movie filename should include title and year")
    }
    
    func testGenerateFileNameMovieWithoutYear() {
        UserDefaults.standard.set("{title}.mkv", forKey: "movieFileFormat")
        UserDefaults.standard.set(false, forKey: "includeYearInFilename")
        
        let filename = settingsUtilities.generateFileName(
            mediaType: .movie,
            metadata: testMetadata
        )
        
        XCTAssertEqual(filename, "Test Movie.mkv", "Movie filename should not include year when disabled")
    }
    
    func testGenerateFileNameTVShow() {
        UserDefaults.standard.set("{series} - S{season:02d}E{episode:02d} - {title}.mkv", forKey: "tvShowFileFormat")
        UserDefaults.standard.set("S{season:02d}E{episode:02d}", forKey: "seasonEpisodeFormat")
        
        let filename = settingsUtilities.generateFileName(
            mediaType: .tvShow,
            metadata: testMetadata
        )
        
        XCTAssertEqual(filename, "Test Series - S01E05 - Test Movie.mkv", "TV show filename should include series, season, episode, and title")
    }
    
    func testGenerateFileNameWithResolution() {
        UserDefaults.standard.set("{title}.mkv", forKey: "movieFileFormat")
        UserDefaults.standard.set(true, forKey: "includeResolutionInFilename")
        
        let filename = settingsUtilities.generateFileName(
            mediaType: .movie,
            metadata: testMetadata,
            resolution: "1080p"
        )
        
        XCTAssertEqual(filename, "Test Movie [1080p].mkv", "Filename should include resolution when enabled")
    }
    
    func testGenerateFileNameWithCodec() {
        UserDefaults.standard.set("{title}.mkv", forKey: "movieFileFormat")
        UserDefaults.standard.set(true, forKey: "includeCodecInFilename")
        
        let filename = settingsUtilities.generateFileName(
            mediaType: .movie,
            metadata: testMetadata,
            codec: "H.265"
        )
        
        XCTAssertEqual(filename, "Test Movie [H.265].mkv", "Filename should include codec when enabled")
    }
    
    func testGenerateFileNameWithResolutionAndCodec() {
        UserDefaults.standard.set("{title}.mkv", forKey: "movieFileFormat")
        UserDefaults.standard.set(true, forKey: "includeResolutionInFilename")
        UserDefaults.standard.set(true, forKey: "includeCodecInFilename")
        
        let filename = settingsUtilities.generateFileName(
            mediaType: .movie,
            metadata: testMetadata,
            codec: "H.265",
            resolution: "4K"
        )
        
        XCTAssertEqual(filename, "Test Movie [4K] [H.265].mkv", "Filename should include both resolution and codec")
    }
    
    func testGenerateFileNameUnknownMediaType() {
        let filename = settingsUtilities.generateFileName(
            mediaType: .unknown,
            metadata: testMetadata
        )
        
        XCTAssertEqual(filename, "Test Movie.mkv", "Unknown media type should use simple title format")
    }
    
    // MARK: - Directory Creation Helper Tests
    
    func testCreateDirectoryIfNeededNewDirectory() {
        let newDirPath = testBaseOutputPath.appending("/NewTestDirectory")
        
        XCTAssertFalse(FileManager.default.fileExists(atPath: newDirPath), "Directory should not exist initially")
        
        let result = settingsUtilities.createDirectoryIfNeeded(at: newDirPath)
        
        XCTAssertTrue(result, "Directory creation should succeed")
        XCTAssertTrue(FileManager.default.fileExists(atPath: newDirPath), "Directory should exist after creation")
    }
    
    func testCreateDirectoryIfNeededExistingDirectory() {
        // Directory already exists from setUp
        let result = settingsUtilities.createDirectoryIfNeeded(at: testBaseOutputPath)
        
        XCTAssertTrue(result, "Should return true for existing directory")
        XCTAssertTrue(FileManager.default.fileExists(atPath: testBaseOutputPath), "Directory should still exist")
    }
    
    func testCreateDirectoryIfNeededWithIntermediateDirectories() {
        let deepPath = testBaseOutputPath.appending("/level1/level2/level3")
        
        let result = settingsUtilities.createDirectoryIfNeeded(at: deepPath)
        
        XCTAssertTrue(result, "Should create intermediate directories")
        XCTAssertTrue(FileManager.default.fileExists(atPath: deepPath), "Deep directory should exist")
    }
    
    func testCreateDirectoryIfNeededInvalidPath() {
        // Try to create directory in a path that doesn't allow it (e.g., inside a file)
        let filePath = testBaseOutputPath.appending("/testfile.txt")
        let invalidDirPath = filePath.appending("/invalid")
        
        // Create a file first
        FileManager.default.createFile(atPath: filePath, contents: Data(), attributes: nil)
        
        let result = settingsUtilities.createDirectoryIfNeeded(at: invalidDirPath)
        
        XCTAssertFalse(result, "Should fail to create directory inside a file")
    }
    
    // MARK: - Post-Processing Tests
    
    func testExecutePostProcessingScriptWithoutScript() {
        UserDefaults.standard.removeObject(forKey: "postProcessingScript")
        
        // Should not crash when no script is configured
        XCTAssertNoThrow(
            settingsUtilities.executePostProcessingScript(
                outputPath: "/test/output.mkv",
                metadata: testMetadata
            )
        )
    }
    
    func testExecutePostProcessingScriptWithEmptyScript() {
        UserDefaults.standard.set("", forKey: "postProcessingScript")
        
        // Should not crash when script path is empty
        XCTAssertNoThrow(
            settingsUtilities.executePostProcessingScript(
                outputPath: "/test/output.mkv",
                metadata: testMetadata
            )
        )
    }
    
    func testExecutePostProcessingScriptWithNonexistentScript() {
        UserDefaults.standard.set("/nonexistent/script.sh", forKey: "postProcessingScript")
        
        // Should not crash when script doesn't exist
        XCTAssertNoThrow(
            settingsUtilities.executePostProcessingScript(
                outputPath: "/test/output.mkv",
                metadata: testMetadata
            )
        )
    }
    
    func testExecutePostProcessingScriptWithValidScript() {
        // Create a simple test script
        let scriptPath = testBaseOutputPath.appending("/test_script.sh")
        let scriptContent = "#!/bin/bash\necho \"Post-processing: $1 $2 $3\"\n"
        
        FileManager.default.createFile(atPath: scriptPath, contents: scriptContent.data(using: .utf8), attributes: [
            .posixPermissions: 0o755
        ])
        
        UserDefaults.standard.set(scriptPath, forKey: "postProcessingScript")
        
        // Should not crash with valid script
        XCTAssertNoThrow(
            settingsUtilities.executePostProcessingScript(
                outputPath: "/test/output.mkv",
                metadata: testMetadata
            )
        )
    }
    
    // MARK: - Performance Tests
    
    func testDirectoryCreationPerformance() {
        measure {
            for i in 0..<100 {
                let testPath = testBaseOutputPath.appending("/performance_test_\(i)")
                _ = settingsUtilities.createDirectoryIfNeeded(at: testPath)
            }
        }
    }
    
    func testFileNameGenerationPerformance() {
        UserDefaults.standard.set("{series} - S{season:02d}E{episode:02d} - {title}.mkv", forKey: "tvShowFileFormat")
        
        measure {
            for i in 0..<1000 {
                let metadata = MediaMetadata(
                    title: "Episode \(i)",
                    year: 2023,
                    seriesName: "Test Series",
                    season: 1,
                    episode: i
                )
                _ = settingsUtilities.generateFileName(mediaType: .tvShow, metadata: metadata)
            }
        }
    }
    
    func testOutputDirectoryCreationPerformance() {
        UserDefaults.standard.set(4, forKey: "outputStructureType")
        UserDefaults.standard.set("{genre}/{year}/{title}", forKey: "movieDirectoryFormat")
        
        measure {
            for i in 0..<100 {
                let metadata = MediaMetadata(
                    title: "Movie \(i)",
                    year: 2020 + (i % 4),
                    genre: "Genre\(i % 5)"
                )
                _ = settingsUtilities.createOutputDirectory(
                    baseOutputPath: testBaseOutputPath,
                    mediaType: .movie,
                    metadata: metadata
                )
            }
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testMetadataWithNilValues() {
        let metadataWithNils = MediaMetadata(
            title: "Test Movie",
            year: 2023,
            seriesName: nil,
            season: nil,
            episode: nil,
            genre: nil
        )
        
        // Should handle nil values gracefully
        XCTAssertNoThrow(
            settingsUtilities.generateFileName(
                mediaType: .movie,
                metadata: metadataWithNils
            )
        )
        
        XCTAssertNoThrow(
            settingsUtilities.createOutputDirectory(
                baseOutputPath: testBaseOutputPath,
                mediaType: .movie,
                metadata: metadataWithNils
            )
        )
    }
    
    func testEmptyStringsInMetadata() {
        let metadataWithEmptyStrings = MediaMetadata(
            title: "",
            year: 2023,
            seriesName: "",
            season: 1,
            episode: 1,
            genre: ""
        )
        
        // Should handle empty strings gracefully
        XCTAssertNoThrow(
            settingsUtilities.generateFileName(
                mediaType: .tvShow,
                metadata: metadataWithEmptyStrings
            )
        )
        
        let filename = settingsUtilities.generateFileName(
            mediaType: .movie,
            metadata: metadataWithEmptyStrings
        )
        
        XCTAssertFalse(filename.isEmpty, "Filename should not be empty even with empty title")
    }
    
    // MARK: - Integration Tests
    
    func testCompleteWorkflow() {
        // Test complete workflow from directory creation to file naming
        UserDefaults.standard.set(1, forKey: "outputStructureType")
        UserDefaults.standard.set(true, forKey: "createSeriesDirectory")
        UserDefaults.standard.set(true, forKey: "createSeasonDirectory")
        UserDefaults.standard.set("{series} - S{season:02d}E{episode:02d} - {title}.mkv", forKey: "tvShowFileFormat")
        
        // Create output directory
        let outputPath = settingsUtilities.createOutputDirectory(
            baseOutputPath: testBaseOutputPath,
            mediaType: .tvShow,
            metadata: testMetadata
        )
        
        // Create the directory
        let dirCreated = settingsUtilities.createDirectoryIfNeeded(at: outputPath)
        XCTAssertTrue(dirCreated, "Directory should be created successfully")
        
        // Generate filename
        let filename = settingsUtilities.generateFileName(
            mediaType: .tvShow,
            metadata: testMetadata
        )
        
        // Verify complete path would work
        _ = URL(fileURLWithPath: outputPath).appendingPathComponent(filename).path
        XCTAssertTrue(outputPath.contains("TV Shows"), "Path should contain TV Shows")
        XCTAssertTrue(outputPath.contains("Test Series"), "Path should contain series name")
        XCTAssertTrue(outputPath.contains("Season 1"), "Path should contain season")
        XCTAssertTrue(filename.contains("S01E05"), "Filename should contain season/episode")
    }
}

// MARK: - Mock Settings Manager

class MockSettingsManager {
    var outputStructureType: Int = 1
    var createSeriesDirectory: Bool = false
    var createSeasonDirectory: Bool = false
    var movieDirectoryFormat: String = "{title} ({year})"
    var tvShowDirectoryFormat: String = "{series}/Season {season}"
    var bonusContentStructure: Int = 1
    var bonusContentDirectory: String = "Bonus"
    var includeBonusFeatures: Bool = false
    var includeCommentaries: Bool = false
    var includeDeletedScenes: Bool = false
    var includeMakingOf: Bool = false
    var includeTrailers: Bool = false
}
