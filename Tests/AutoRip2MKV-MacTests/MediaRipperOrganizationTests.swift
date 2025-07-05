import XCTest
import Foundation
@testable import AutoRip2MKV_Mac

final class MediaRipperOrganizationTests: XCTestCase {
    
    var mediaRipper: MediaRipper!
    var testBlurayPath: String!
    var testDVDPath: String!
    var testOutputPath: String!
    
    override func setUpWithError() throws {
        mediaRipper = MediaRipper()
        
        // Create test paths
        let tempDir = NSTemporaryDirectory()
        testBlurayPath = tempDir.appending("MediaRipperOrgTests_BluRay")
        testDVDPath = tempDir.appending("MediaRipperOrgTests_DVD")
        testOutputPath = tempDir.appending("MediaRipperOrgTests_Output")
        
        // Create test Blu-ray structure
        try createTestBlurayStructure()
        
        // Create test DVD structure  
        try createTestDVDStructure()
        
        // Create output directory
        try FileManager.default.createDirectory(atPath: testOutputPath, withIntermediateDirectories: true)
    }
    
    override func tearDownWithError() throws {
        mediaRipper = nil
        
        // Clean up test directories
        try? FileManager.default.removeItem(atPath: testBlurayPath)
        try? FileManager.default.removeItem(atPath: testDVDPath)
        try? FileManager.default.removeItem(atPath: testOutputPath)
    }
    
    // MARK: - Ultra HD Detection Tests
    
    func testIsUltraHDBluRayWithUHDMarkers() {
        // Create test index.bdmv with UHD markers
        let bdmvPath = testBlurayPath.appending("/BDMV")
        let indexPath = bdmvPath.appending("/index.bdmv")
        
        // Create data with UHD marker
        var indexData = Data(repeating: 0x00, count: 1024)
        let uhdMarker = Data([0x0F, 0x00])
        indexData.replaceSubrange(100..<102, with: uhdMarker)
        
        try! indexData.write(to: URL(fileURLWithPath: indexPath))
        
        let result = mediaRipper.isUltraHDBluRay(bdmvPath: bdmvPath)
        XCTAssertTrue(result, "Should detect UHD Blu-ray with UHD marker")
    }
    
    func testIsUltraHDBluRayWith4KResolution() {
        let bdmvPath = testBlurayPath.appending("/BDMV")
        let indexPath = bdmvPath.appending("/index.bdmv")
        
        // Create data with 4K resolution markers
        var indexData = Data(repeating: 0x00, count: 1024)
        let resolution4K = "3840".data(using: .utf8)!
        indexData.replaceSubrange(200..<204, with: resolution4K)
        
        try! indexData.write(to: URL(fileURLWithPath: indexPath))
        
        let result = mediaRipper.isUltraHDBluRay(bdmvPath: bdmvPath)
        XCTAssertTrue(result, "Should detect UHD Blu-ray with 4K resolution marker")
    }
    
    func testIsUltraHDBluRayWithCertificate() {
        let bdmvPath = testBlurayPath.appending("/BDMV")
        let certificatePath = bdmvPath.appending("/CERTIFICATE")
        let idPath = certificatePath.appending("/id.bdmv")
        
        // Create certificate structure
        try! FileManager.default.createDirectory(atPath: certificatePath, withIntermediateDirectories: true)
        try! Data().write(to: URL(fileURLWithPath: idPath))
        
        let result = mediaRipper.isUltraHDBluRay(bdmvPath: bdmvPath)
        XCTAssertTrue(result, "Should detect UHD Blu-ray with certificate structure")
    }
    
    func testIsUltraHDBluRayRegularBluRay() {
        let bdmvPath = testBlurayPath.appending("/BDMV")
        
        let result = mediaRipper.isUltraHDBluRay(bdmvPath: bdmvPath)
        XCTAssertFalse(result, "Should not detect regular Blu-ray as UHD")
    }
    
    func testIsUltraHDBluRayInvalidPath() {
        let result = mediaRipper.isUltraHDBluRay(bdmvPath: "/invalid/path")
        XCTAssertFalse(result, "Should return false for invalid path")
    }
    
    func testIsUltraHDDVDWithHDMarkers() {
        let videoTSPath = testDVDPath.appending("/VIDEO_TS")
        let vmgiPath = videoTSPath.appending("/VIDEO_TS.IFO")
        
        // Create data with HD marker
        var vmgiData = Data(repeating: 0x00, count: 1024)
        let hdMarker = Data([0x04, 0x00])
        vmgiData.replaceSubrange(100..<102, with: hdMarker)
        
        try! vmgiData.write(to: URL(fileURLWithPath: vmgiPath))
        
        let result = mediaRipper.isUltraHDDVD(videoTSPath: videoTSPath)
        XCTAssertTrue(result, "Should detect Ultra HD DVD with HD marker")
    }
    
    func testIsUltraHDDVDRegularDVD() {
        let videoTSPath = testDVDPath.appending("/VIDEO_TS")
        
        let result = mediaRipper.isUltraHDDVD(videoTSPath: videoTSPath)
        XCTAssertFalse(result, "Should not detect regular DVD as Ultra HD")
    }
    
    func testIsUltraHDDVDInvalidPath() {
        let result = mediaRipper.isUltraHDDVD(videoTSPath: "/invalid/path")
        XCTAssertFalse(result, "Should return false for invalid path")
    }
    
    // MARK: - Movie Name Extraction Tests
    
    func testExtractMovieNameFromVolumeLabel() {
        // Test with a mock volume label (this is hard to test without actual mounting)
        let movieName = mediaRipper.extractMovieName(from: testBlurayPath, mediaType: .bluray)
        
        // Should return a valid name (fallback to timestamp if no title found)
        XCTAssertFalse(movieName.isEmpty, "Movie name should not be empty")
        // The extracted name might be the fallback format with media type and timestamp
        XCTAssertTrue(movieName.contains("Blu") || movieName.contains("20") || movieName.count > 3, "Should contain media type, timestamp, or valid title")
    }
    
    func testExtractMovieNameFallbackFormat() {
        // Test fallback naming with timestamp
        let movieName = mediaRipper.extractMovieName(from: "/invalid/path", mediaType: .dvd)
        
        XCTAssertTrue(movieName.contains("DVD"), "Fallback name should contain media type")
        XCTAssertTrue(movieName.contains("-"), "Fallback name should contain timestamp separator")
    }
    
    func testSanitizeMovieName() {
        // This tests the private method indirectly through extractMovieName
        // We can't test the private method directly, but we can verify the behavior
        let movieName = mediaRipper.extractMovieName(from: testBlurayPath, mediaType: .bluray)
        
        // Verify no invalid characters
        let invalidChars = CharacterSet(charactersIn: "/:*?\"<>|\\")
        XCTAssertTrue(movieName.rangeOfCharacter(from: invalidChars) == nil, 
                     "Movie name should not contain invalid file system characters")
    }
    
    // MARK: - Cover Art Extraction Tests
    
    func testExtractCoverArtBluray() {
        // Create mock cover art
        let metaPath = testBlurayPath.appending("/BDMV/META/DL")
        try! FileManager.default.createDirectory(atPath: metaPath, withIntermediateDirectories: true)
        
        let coverPath = metaPath.appending("/cover.jpg")
        let mockImageData = Data([0xFF, 0xD8, 0xFF, 0xE0]) // JPEG header
        try! mockImageData.write(to: URL(fileURLWithPath: coverPath))
        
        // Set media type to Blu-ray
        mediaRipper.currentMediaType = .bluray
        
        XCTAssertNoThrow(mediaRipper.extractCoverArt(from: testBlurayPath, to: testOutputPath))
        
        // Check if cover art was copied
        let destinationPath = testOutputPath.appending("/cover.jpg")
        XCTAssertTrue(FileManager.default.fileExists(atPath: destinationPath), 
                     "Cover art should be copied to output directory")
    }
    
    func testExtractCoverArtNonBluray() {
        // Set media type to DVD (should not extract cover art)
        mediaRipper.currentMediaType = .dvd
        
        XCTAssertNoThrow(mediaRipper.extractCoverArt(from: testDVDPath, to: testOutputPath))
        
        // Should not create any cover files
        let destinationPath = testOutputPath.appending("/cover.jpg")
        XCTAssertFalse(FileManager.default.fileExists(atPath: destinationPath), 
                      "Cover art should not be extracted for non-Blu-ray media")
    }
    
    func testExtractCoverArtNoCoverAvailable() {
        // Set media type to Blu-ray but no cover art available
        mediaRipper.currentMediaType = .bluray
        
        XCTAssertNoThrow(mediaRipper.extractCoverArt(from: testBlurayPath, to: testOutputPath))
        
        // Should not create cover files when none available
        let destinationPath = testOutputPath.appending("/cover.jpg")
        XCTAssertFalse(FileManager.default.fileExists(atPath: destinationPath), 
                      "Should not create cover art when none available")
    }
    
    // MARK: - Directory Organization Tests
    
    func testCreateOrganizedOutputDirectoryDVD() {
        let movieName = "Test Movie"
        let result = mediaRipper.createOrganizedOutputDirectory(
            baseDirectory: testOutputPath,
            mediaType: .dvd,
            movieName: movieName
        )
        
        let expectedPath = testOutputPath.appending("/DVD/\(movieName)")
        XCTAssertEqual(result, expectedPath, "Should create organized DVD directory")
        XCTAssertTrue(FileManager.default.fileExists(atPath: result), "Directory should be created")
    }
    
    func testCreateOrganizedOutputDirectoryUltraHDDVD() {
        let movieName = "Test Ultra HD DVD"
        let result = mediaRipper.createOrganizedOutputDirectory(
            baseDirectory: testOutputPath,
            mediaType: .ultraHDDVD,
            movieName: movieName
        )
        
        let expectedPath = testOutputPath.appending("/Ultra_HD_DVD/\(movieName)")
        XCTAssertEqual(result, expectedPath, "Should create organized Ultra HD DVD directory")
        XCTAssertTrue(FileManager.default.fileExists(atPath: result), "Directory should be created")
    }
    
    func testCreateOrganizedOutputDirectoryBluray() {
        let movieName = "Test Bluray"
        let result = mediaRipper.createOrganizedOutputDirectory(
            baseDirectory: testOutputPath,
            mediaType: .bluray,
            movieName: movieName
        )
        
        let expectedPath = testOutputPath.appending("/Blu-ray/\(movieName)")
        XCTAssertEqual(result, expectedPath, "Should create organized Blu-ray directory")
        XCTAssertTrue(FileManager.default.fileExists(atPath: result), "Directory should be created")
    }
    
    func testCreateOrganizedOutputDirectoryBluray4K() {
        let movieName = "Test 4K Movie"
        let result = mediaRipper.createOrganizedOutputDirectory(
            baseDirectory: testOutputPath,
            mediaType: .bluray4K,
            movieName: movieName
        )
        
        let expectedPath = testOutputPath.appending("/4K_Blu-ray/\(movieName)")
        XCTAssertEqual(result, expectedPath, "Should create organized 4K Blu-ray directory")
        XCTAssertTrue(FileManager.default.fileExists(atPath: result), "Directory should be created")
    }
    
    func testCreateOrganizedOutputDirectoryUnknown() {
        let movieName = "Test Unknown"
        let result = mediaRipper.createOrganizedOutputDirectory(
            baseDirectory: testOutputPath,
            mediaType: .unknown,
            movieName: movieName
        )
        
        let expectedPath = testOutputPath.appending("/Unknown_Media/\(movieName)")
        XCTAssertEqual(result, expectedPath, "Should create organized unknown media directory")
        XCTAssertTrue(FileManager.default.fileExists(atPath: result), "Directory should be created")
    }
    
    func testCreateOrganizedOutputDirectoryCreationFailure() {
        // Try to create directory in invalid location
        let result = mediaRipper.createOrganizedOutputDirectory(
            baseDirectory: "/invalid/permission/denied",
            mediaType: .dvd,
            movieName: "Test Movie"
        )
        
        // Should fallback to base directory on failure
        XCTAssertEqual(result, "/invalid/permission/denied", "Should fallback to base directory on failure")
    }
    
    // MARK: - Disc Info Tests
    
    func testCreateDiscInfo() {
        let movieName = "Test Movie"
        
        XCTAssertNoThrow(mediaRipper.createDiscInfo(
            in: testOutputPath,
            mediaPath: testBlurayPath,
            mediaType: .bluray,
            movieName: movieName
        ))
        
        let infoPath = testOutputPath.appending("/disc_info.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: infoPath), "Disc info file should be created")
        
        // Verify JSON content
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: infoPath))
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            
            XCTAssertNotNil(json, "Should be valid JSON")
            XCTAssertEqual(json?["movie_name"] as? String, movieName, "Should contain movie name")
            XCTAssertEqual(json?["media_type"] as? String, "Blu-ray", "Should contain media type")
            XCTAssertEqual(json?["source_path"] as? String, testBlurayPath, "Should contain source path")
            XCTAssertNotNil(json?["rip_date"], "Should contain rip date")
            XCTAssertNotNil(json?["ripper_version"], "Should contain ripper version")
        } catch {
            XCTFail("Failed to parse disc info JSON: \(error)")
        }
    }
    
    func testCreateDiscInfoInvalidDirectory() {
        // Test with invalid directory (should not crash)
        XCTAssertNoThrow(mediaRipper.createDiscInfo(
            in: "/invalid/directory",
            mediaPath: testBlurayPath,
            mediaType: .bluray,
            movieName: "Test Movie"
        ))
    }
    
    // MARK: - Performance Tests
    
    func testUltraHDDetectionPerformance() {
        let bdmvPath = testBlurayPath.appending("/BDMV")
        
        measure {
            for _ in 0..<100 {
                _ = mediaRipper.isUltraHDBluRay(bdmvPath: bdmvPath)
            }
        }
    }
    
    func testMovieNameExtractionPerformance() {
        measure {
            for _ in 0..<100 {
                _ = mediaRipper.extractMovieName(from: testBlurayPath, mediaType: .bluray)
            }
        }
    }
    
    func testDirectoryCreationPerformance() {
        measure {
            for i in 0..<50 {
                let movieName = "Test Movie \(i)"
                let outputDir = testOutputPath.appending("/perf_test_\(i)")
                try! FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)
                
                _ = mediaRipper.createOrganizedOutputDirectory(
                    baseDirectory: outputDir,
                    mediaType: .dvd,
                    movieName: movieName
                )
            }
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testExtractMovieNameWithEmptyPath() {
        let movieName = mediaRipper.extractMovieName(from: "", mediaType: .bluray)
        XCTAssertFalse(movieName.isEmpty, "Should provide fallback name for empty path")
    }
    
    func testCoverArtExtractionWithInvalidPath() {
        mediaRipper.currentMediaType = .bluray
        
        XCTAssertNoThrow(mediaRipper.extractCoverArt(from: "/invalid/path", to: testOutputPath))
    }
    
    func testDiscInfoCreationWithInvalidMediaPath() {
        XCTAssertNoThrow(mediaRipper.createDiscInfo(
            in: testOutputPath,
            mediaPath: "/invalid/path",
            mediaType: .bluray,
            movieName: "Test Movie"
        ))
        
        // Should still create info file with invalid path
        let infoPath = testOutputPath.appending("/disc_info.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: infoPath), "Should create disc info even with invalid media path")
    }
    
    // MARK: - Integration Tests
    
    func testCompleteOrganizationWorkflow() {
        // Test complete workflow: detect UHD, extract name, organize directory, create info
        mediaRipper.currentMediaType = .bluray
        
        // Extract movie name
        let movieName = mediaRipper.extractMovieName(from: testBlurayPath, mediaType: .bluray)
        XCTAssertFalse(movieName.isEmpty, "Movie name should be extracted")
        
        // Create organized directory
        let outputDir = mediaRipper.createOrganizedOutputDirectory(
            baseDirectory: testOutputPath,
            mediaType: .bluray,
            movieName: movieName
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputDir), "Output directory should be created")
        
        // Extract cover art (if available)
        XCTAssertNoThrow(mediaRipper.extractCoverArt(from: testBlurayPath, to: outputDir))
        
        // Create disc info
        XCTAssertNoThrow(mediaRipper.createDiscInfo(
            in: outputDir,
            mediaPath: testBlurayPath,
            mediaType: .bluray,
            movieName: movieName
        ))
        
        let infoPath = outputDir.appending("/disc_info.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: infoPath), "Disc info should be created")
    }
    
    // MARK: - Test Data Creation Helpers
    
    private func createTestBlurayStructure() throws {
        let bdmvPath = testBlurayPath.appending("/BDMV")
        let metaPath = bdmvPath.appending("/META/DL")
        
        try FileManager.default.createDirectory(atPath: metaPath, withIntermediateDirectories: true)
        
        // Create minimal index.bdmv
        let indexData = Data(repeating: 0x00, count: 1024)
        try indexData.write(to: URL(fileURLWithPath: bdmvPath.appending("/index.bdmv")))
    }
    
    private func createTestDVDStructure() throws {
        let videoTSPath = testDVDPath.appending("/VIDEO_TS")
        try FileManager.default.createDirectory(atPath: videoTSPath, withIntermediateDirectories: true)
        
        // Create minimal VIDEO_TS.IFO
        let vmgiData = Data(repeating: 0x00, count: 1024)
        try vmgiData.write(to: URL(fileURLWithPath: videoTSPath.appending("/VIDEO_TS.IFO")))
    }
}

// Note: MediaType extension is not needed as it's already defined in MediaRipper.swift
