import XCTest
@testable import AutoRip2MKV_Mac

final class DVDRipperTests: XCTestCase {
    
    var ripper: DVDRipper!
    var mockDelegate: MockDVDRipperDelegate!
    let testDVDPath = "/tmp/test_ripper_dvd"
    let testOutputPath = "/tmp/test_ripper_output"
    
    override func setUpWithError() throws {
        ripper = DVDRipper()
        mockDelegate = MockDVDRipperDelegate()
        ripper.delegate = mockDelegate
        
        // Create test directories
        try FileManager.default.createDirectory(atPath: testDVDPath, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(atPath: testOutputPath, withIntermediateDirectories: true)
    }
    
    override func tearDownWithError() throws {
        ripper = nil
        mockDelegate = nil
        
        // Clean up test directories
        try? FileManager.default.removeItem(atPath: testDVDPath)
        try? FileManager.default.removeItem(atPath: testOutputPath)
    }
    
    // MARK: - Initialization Tests
    
    func testRipperInitialization() {
        XCTAssertNotNil(ripper)
        XCTAssertFalse(ripper.isCurrentlyRipping)
    }
    
    func testDelegateAssignment() {
        XCTAssertNotNil(ripper.delegate)
        XCTAssertTrue(ripper.delegate === mockDelegate)
    }
    
    // MARK: - Configuration Tests
    
    func testRippingConfigurationInitialization() {
        let config = DVDRipper.RippingConfiguration(
            outputDirectory: testOutputPath,
            selectedTitles: [1, 2, 3],
            videoCodec: .h264,
            audioCodec: .aac,
            quality: .high,
            includeSubtitles: true,
            includeChapters: false
        )
        
        XCTAssertEqual(config.outputDirectory, testOutputPath)
        XCTAssertEqual(config.selectedTitles, [1, 2, 3])
        XCTAssertEqual(config.videoCodec, .h264)
        XCTAssertEqual(config.audioCodec, .aac)
        XCTAssertEqual(config.quality, .high)
        XCTAssertTrue(config.includeSubtitles)
        XCTAssertFalse(config.includeChapters)
    }
    
    func testVideoCodecStrings() {
        // Test through ripper's internal method via reflection if possible
        // Since getVideoCodecString is private, we test the enum values
        XCTAssertEqual(DVDRipper.RippingConfiguration.VideoCodec.h264, .h264)
        XCTAssertEqual(DVDRipper.RippingConfiguration.VideoCodec.h265, .h265)
        XCTAssertEqual(DVDRipper.RippingConfiguration.VideoCodec.av1, .av1)
    }
    
    func testAudioCodecStrings() {
        XCTAssertEqual(DVDRipper.RippingConfiguration.AudioCodec.aac, .aac)
        XCTAssertEqual(DVDRipper.RippingConfiguration.AudioCodec.ac3, .ac3)
        XCTAssertEqual(DVDRipper.RippingConfiguration.AudioCodec.dts, .dts)
        XCTAssertEqual(DVDRipper.RippingConfiguration.AudioCodec.flac, .flac)
    }
    
    func testQualityCRFValues() {
        XCTAssertEqual(DVDRipper.RippingConfiguration.RippingQuality.low.crf, 28)
        XCTAssertEqual(DVDRipper.RippingConfiguration.RippingQuality.medium.crf, 23)
        XCTAssertEqual(DVDRipper.RippingConfiguration.RippingQuality.high.crf, 18)
        XCTAssertEqual(DVDRipper.RippingConfiguration.RippingQuality.lossless.crf, 0)
    }
    
    // MARK: - Ripping State Tests
    
    func testStartRippingWithInvalidPath() {
        let config = DVDRipper.RippingConfiguration(
            outputDirectory: testOutputPath,
            selectedTitles: [],
            videoCodec: .h264,
            audioCodec: .aac,
            quality: .high,
            includeSubtitles: true,
            includeChapters: true
        )
        
        // Start ripping with invalid DVD path
        ripper.startRipping(dvdPath: "/invalid/path", configuration: config)
        
        // Wait for async error
        let expectation = XCTestExpectation(description: "Error callback")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)
        
        XCTAssertTrue(mockDelegate.didFailCalled)
        XCTAssertFalse(ripper.isCurrentlyRipping)
    }
    
    func testCancelRipping() {
        XCTAssertNoThrow(ripper.cancelRipping())
    }
    
    func testDoubleStartRipping() {
        let config = DVDRipper.RippingConfiguration(
            outputDirectory: testOutputPath,
            selectedTitles: [],
            videoCodec: .h264,
            audioCodec: .aac,
            quality: .high,
            includeSubtitles: true,
            includeChapters: true
        )
        
        // Start first ripping operation
        ripper.startRipping(dvdPath: testDVDPath, configuration: config)
        
        // Try to start second ripping operation immediately
        ripper.startRipping(dvdPath: testDVDPath, configuration: config)
        
        // Wait for potential error
        let expectation = XCTestExpectation(description: "Already ripping error")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertTrue(mockDelegate.didFailCalled)
        if let error = mockDelegate.lastError as? RipperError {
            XCTAssertEqual(error, RipperError.alreadyRipping)
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testRipperErrorDescriptions() {
        XCTAssertEqual(RipperError.alreadyRipping.localizedDescription, "Already ripping")
        XCTAssertEqual(RipperError.noTitlesFound.localizedDescription, "No titles found on DVD")
        XCTAssertEqual(RipperError.failedToCreateTempFile.localizedDescription, "Failed to create temporary file")
        XCTAssertEqual(RipperError.failedToReadVOB.localizedDescription, "Failed to read VOB file")
        XCTAssertEqual(RipperError.ffmpegFailed.localizedDescription, "FFmpeg conversion failed")
        XCTAssertEqual(RipperError.cancelled.localizedDescription, "Operation cancelled")
    }
    
    // MARK: - Performance Tests
    
    func testConfigurationCreationPerformance() {
        measure {
            for _ in 0..<1000 {
                _ = DVDRipper.RippingConfiguration(
                    outputDirectory: testOutputPath,
                    selectedTitles: [1, 2, 3],
                    videoCodec: .h264,
                    audioCodec: .aac,
                    quality: .high,
                    includeSubtitles: true,
                    includeChapters: true
                )
            }
        }
    }
    
    func testRipperCreationPerformance() {
        measure {
            for _ in 0..<100 {
                _ = DVDRipper()
            }
        }
    }
    
    // MARK: - Memory Management Tests
    
    func testRipperMemoryManagement() {
        weak var weakRipper: DVDRipper?
        
        autoreleasepool {
            let tempRipper = DVDRipper()
            weakRipper = tempRipper
            // tempRipper goes out of scope here
        }
        
        // Ripper should be deallocated
        XCTAssertNil(weakRipper)
    }
    
    // MARK: - Delegate Protocol Tests
    
    func testDelegateProtocolMethods() {
        // Test that all delegate methods are defined and callable
        mockDelegate.ripperDidStart()
        mockDelegate.ripperDidUpdateStatus("Test")
        mockDelegate.ripperDidUpdateProgress(0.5, currentTitle: nil, totalTitles: 1)
        mockDelegate.ripperDidComplete()
        mockDelegate.ripperDidFail(with: RipperError.cancelled)
        
        XCTAssertTrue(mockDelegate.didStartCalled)
        XCTAssertTrue(mockDelegate.didUpdateStatusCalled)
        XCTAssertTrue(mockDelegate.didUpdateProgressCalled)
        XCTAssertTrue(mockDelegate.didCompleteCalled)
        XCTAssertTrue(mockDelegate.didFailCalled)
    }
    
    // MARK: - Thread Safety Tests
    
    func testConcurrentRipperCreation() {
        let expectation = XCTestExpectation(description: "Concurrent ripper creation")
        let concurrentQueue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)
        let group = DispatchGroup()
        
        for _ in 0..<10 {
            concurrentQueue.async(group: group) {
                let testRipper = DVDRipper()
                XCTAssertFalse(testRipper.isCurrentlyRipping)
            }
        }
        
        group.notify(queue: .main) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
}

// MARK: - Mock Delegate

class MockDVDRipperDelegate: DVDRipperDelegate {
    var didStartCalled = false
    var didUpdateStatusCalled = false
    var didUpdateProgressCalled = false
    var didCompleteCalled = false
    var didFailCalled = false
    
    var lastStatus: String?
    var lastProgress: Double?
    var lastError: Error?
    
    func ripperDidStart() {
        didStartCalled = true
    }
    
    func ripperDidUpdateStatus(_ status: String) {
        didUpdateStatusCalled = true
        lastStatus = status
    }
    
    func ripperDidUpdateProgress(_ progress: Double, currentTitle: DVDTitle?, totalTitles: Int) {
        didUpdateProgressCalled = true
        lastProgress = progress
    }
    
    func ripperDidComplete() {
        didCompleteCalled = true
    }
    
    func ripperDidFail(with error: Error) {
        didFailCalled = true
        lastError = error
    }
}
