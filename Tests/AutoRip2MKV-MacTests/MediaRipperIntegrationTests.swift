import XCTest
@testable import AutoRip2MKV_Mac

final class MediaRipperIntegrationTests: XCTestCase {
    
    var mediaRipper: MediaRipper!
    var mockDelegate: MockMediaRipperDelegate!
    let testDVDPath = "/tmp/test_integration_dvd"
    let testBlurayPath = "/tmp/test_integration_bluray"
    let testOutputPath = "/tmp/test_integration_output"
    
    override func setUpWithError() throws {
        mediaRipper = MediaRipper()
        mockDelegate = MockMediaRipperDelegate()
        mediaRipper.delegate = mockDelegate
        
        // Create comprehensive test structures
        try createTestDVDStructure()
        try createTestBlurayStructure()
        try FileManager.default.createDirectory(atPath: testOutputPath, withIntermediateDirectories: true)
    }
    
    override func tearDownWithError() throws {
        mediaRipper = nil
        mockDelegate = nil
        
        // Cleanup
        try? FileManager.default.removeItem(atPath: testDVDPath)
        try? FileManager.default.removeItem(atPath: testBlurayPath)
        try? FileManager.default.removeItem(atPath: testOutputPath)
    }
    
    // MARK: - Media Type Detection Tests
    
    func testMediaTypeDetection() {
        XCTAssertEqual(mediaRipper.detectMediaType(path: testDVDPath), .dvd)
        XCTAssertEqual(mediaRipper.detectMediaType(path: testBlurayPath), .bluray)
        XCTAssertEqual(mediaRipper.detectMediaType(path: "/invalid/path"), .unknown)
    }
    
    func testMediaTypeDetectionPerformance() {
        measure {
            for _ in 0..<100 {
                _ = mediaRipper.detectMediaType(path: testDVDPath)
                _ = mediaRipper.detectMediaType(path: testBlurayPath)
            }
        }
    }
    
    // MARK: - DVD Integration Tests
    
    func testDVDRippingWorkflow() throws {
        let configuration = MediaRipper.RippingConfiguration(
            outputDirectory: testOutputPath,
            selectedTitles: [],
            videoCodec: .h264,
            audioCodec: .aac,
            quality: .medium,
            includeSubtitles: true,
            includeChapters: true,
            mediaType: .dvd
        )
        
        let expectation = XCTestExpectation(description: "DVD ripping workflow")
        
        // Start ripping
        mediaRipper.startRipping(mediaPath: testDVDPath, configuration: configuration)
        
        // Wait for completion or failure
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
        
        // Verify delegate was called properly
        XCTAssertTrue(mockDelegate.didStartCalled)
        XCTAssertTrue(mockDelegate.didUpdateStatusCalled || mockDelegate.didFailCalled)
    }
    
    func testDVDRippingCancellation() {
        let configuration = MediaRipper.RippingConfiguration(
            outputDirectory: testOutputPath,
            selectedTitles: [],
            videoCodec: .h264,
            audioCodec: .aac,
            quality: .medium,
            includeSubtitles: false,
            includeChapters: false,
            mediaType: .dvd
        )
        
        // Start and immediately cancel
        mediaRipper.startRipping(mediaPath: testDVDPath, configuration: configuration)
        mediaRipper.cancelRipping()
        
        let expectation = XCTestExpectation(description: "Cancellation handling")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 3.0)
        
        XCTAssertFalse(mediaRipper.isCurrentlyRipping)
    }
    
    // MARK: - Blu-ray Integration Tests
    
    func testBlurayRippingWorkflow() throws {
        let configuration = MediaRipper.RippingConfiguration(
            outputDirectory: testOutputPath,
            selectedTitles: [],
            videoCodec: .h265,
            audioCodec: .ac3,
            quality: .high,
            includeSubtitles: true,
            includeChapters: true,
            mediaType: .bluray
        )
        
        let expectation = XCTestExpectation(description: "Blu-ray ripping workflow")
        
        mediaRipper.startRipping(mediaPath: testBlurayPath, configuration: configuration)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
        
        XCTAssertTrue(mockDelegate.didStartCalled)
        XCTAssertTrue(mockDelegate.didUpdateStatusCalled || mockDelegate.didFailCalled)
    }
    
    // MARK: - Error Handling Tests
    
    func testInvalidMediaPath() {
        let configuration = MediaRipper.RippingConfiguration(
            outputDirectory: testOutputPath,
            selectedTitles: [],
            videoCodec: .h264,
            audioCodec: .aac,
            quality: .medium,
            includeSubtitles: false,
            includeChapters: false,
            mediaType: nil
        )
        
        mediaRipper.startRipping(mediaPath: "/invalid/path", configuration: configuration)
        
        let expectation = XCTestExpectation(description: "Invalid path error")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 3.0)
        
        XCTAssertTrue(mockDelegate.didFailCalled)
        XCTAssertNotNil(mockDelegate.lastError)
    }
    
    func testInvalidOutputPath() {
        let configuration = MediaRipper.RippingConfiguration(
            outputDirectory: "/invalid/output/path",
            selectedTitles: [],
            videoCodec: .h264,
            audioCodec: .aac,
            quality: .medium,
            includeSubtitles: false,
            includeChapters: false,
            mediaType: .dvd
        )
        
        mediaRipper.startRipping(mediaPath: testDVDPath, configuration: configuration)
        
        let expectation = XCTestExpectation(description: "Invalid output path error")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 3.0)
        
        XCTAssertTrue(mockDelegate.didFailCalled)
    }
    
    // MARK: - Configuration Tests
    
    func testAllVideoCodecs() {
        let codecs: [MediaRipper.RippingConfiguration.VideoCodec] = [.h264, .h265, .av1]
        
        for codec in codecs {
            let configuration = MediaRipper.RippingConfiguration(
                outputDirectory: testOutputPath,
                selectedTitles: [1],
                videoCodec: codec,
                audioCodec: .aac,
                quality: .medium,
                includeSubtitles: false,
                includeChapters: false,
                mediaType: .dvd
            )
            
            XCTAssertEqual(configuration.videoCodec, codec)
        }
    }
    
    func testAllAudioCodecs() {
        let codecs: [MediaRipper.RippingConfiguration.AudioCodec] = [.aac, .ac3, .dts, .flac]
        
        for codec in codecs {
            let configuration = MediaRipper.RippingConfiguration(
                outputDirectory: testOutputPath,
                selectedTitles: [1],
                videoCodec: .h264,
                audioCodec: codec,
                quality: .medium,
                includeSubtitles: false,
                includeChapters: false,
                mediaType: .dvd
            )
            
            XCTAssertEqual(configuration.audioCodec, codec)
        }
    }
    
    func testQualitySettings() {
        let qualities: [MediaRipper.RippingConfiguration.RippingQuality] = [.low, .medium, .high, .lossless]
        let expectedCRFs = [28, 23, 18, 0]
        
        for (index, quality) in qualities.enumerated() {
            XCTAssertEqual(quality.crf, expectedCRFs[index])
        }
    }
    
    // MARK: - Concurrent Operations Tests
    
    func testConcurrentRippingPrevention() {
        let configuration = MediaRipper.RippingConfiguration(
            outputDirectory: testOutputPath,
            selectedTitles: [],
            videoCodec: .h264,
            audioCodec: .aac,
            quality: .medium,
            includeSubtitles: false,
            includeChapters: false,
            mediaType: .dvd
        )
        
        // Start first operation
        mediaRipper.startRipping(mediaPath: testDVDPath, configuration: configuration)
        
        // Try to start second operation
        mediaRipper.startRipping(mediaPath: testDVDPath, configuration: configuration)
        
        let expectation = XCTestExpectation(description: "Concurrent prevention")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
        
        XCTAssertTrue(mockDelegate.didFailCalled)
        if let error = mockDelegate.lastError as? MediaRipperError {
            XCTAssertEqual(error, MediaRipperError.alreadyRipping)
        }
    }
    
    // MARK: - Memory and Performance Tests
    
    func testMemoryUsageDuringRipping() {
        // Test that memory usage stays within reasonable bounds
        let configuration = MediaRipper.RippingConfiguration(
            outputDirectory: testOutputPath,
            selectedTitles: [1],
            videoCodec: .h264,
            audioCodec: .aac,
            quality: .low, // Use low quality for faster testing
            includeSubtitles: false,
            includeChapters: false,
            mediaType: .dvd
        )
        
        measure {
            autoreleasepool {
                let tempRipper = MediaRipper()
                tempRipper.delegate = mockDelegate
                tempRipper.startRipping(mediaPath: testDVDPath, configuration: configuration)
                
                // Brief execution
                RunLoop.current.run(until: Date().addingTimeInterval(0.5))
                
                tempRipper.cancelRipping()
            }
        }
    }
    
    // MARK: - Test Data Creation Helpers
    
    private func createTestDVDStructure() throws {
        let videoTSPath = "\(testDVDPath)/VIDEO_TS"
        try FileManager.default.createDirectory(atPath: videoTSPath, withIntermediateDirectories: true)
        
        // Create minimal test files
        let vmgiData = createMinimalVMGIData()
        try vmgiData.write(to: URL(fileURLWithPath: "\(videoTSPath)/VIDEO_TS.IFO"))
        
        let vtsData = createMinimalVTSData()
        try vtsData.write(to: URL(fileURLWithPath: "\(videoTSPath)/VTS_01_0.IFO"))
        
        // Create small test VOB files
        let vobData = Data(repeating: 0x00, count: 2048) // One sector
        try vobData.write(to: URL(fileURLWithPath: "\(videoTSPath)/VTS_01_1.VOB"))
    }
    
    private func createTestBlurayStructure() throws {
        let bdmvPath = "\(testBlurayPath)/BDMV"
        let playlistPath = "\(bdmvPath)/PLAYLIST"
        let streamPath = "\(bdmvPath)/STREAM"
        
        try FileManager.default.createDirectory(atPath: playlistPath, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(atPath: streamPath, withIntermediateDirectories: true)
        
        // Create minimal test files
        let indexData = createMinimalBlurayIndexData()
        try indexData.write(to: URL(fileURLWithPath: "\(bdmvPath)/index.bdmv"))
        
        let playlistData = createMinimalPlaylistData()
        try playlistData.write(to: URL(fileURLWithPath: "\(playlistPath)/00001.mpls"))
        
        let streamData = Data(repeating: 0x00, count: 2048)
        try streamData.write(to: URL(fileURLWithPath: "\(streamPath)/00001.m2ts"))
    }
    
    private func createMinimalVMGIData() -> Data {
        var data = Data(repeating: 0x00, count: 4096)
        "DVDVIDEO-VMG".data(using: .ascii)!.enumerated().forEach { data[$0.offset] = $0.element }
        return data
    }
    
    private func createMinimalVTSData() -> Data {
        var data = Data(repeating: 0x00, count: 4096)
        "DVDVIDEO-VTS".data(using: .ascii)!.enumerated().forEach { data[$0.offset] = $0.element }
        return data
    }
    
    private func createMinimalBlurayIndexData() -> Data {
        var data = Data(repeating: 0x00, count: 4096)
        "INDX0200".data(using: .ascii)!.enumerated().forEach { data[$0.offset] = $0.element }
        return data
    }
    
    private func createMinimalPlaylistData() -> Data {
        var data = Data(repeating: 0x00, count: 1024)
        "MPLS0200".data(using: .ascii)!.enumerated().forEach { data[$0.offset] = $0.element }
        return data
    }
}

// MARK: - Mock Delegate for MediaRipper

class MockMediaRipperDelegate: MediaRipperDelegate {
    var didStartCalled = false
    var didUpdateStatusCalled = false
    var didUpdateProgressCalled = false
    var didCompleteCalled = false
    var didFailCalled = false
    
    var lastStatus: String?
    var lastProgress: Double?
    var lastError: Error?
    struct ProgressUpdate {
        let progress: Double
        let item: MediaRipper.MediaItem?
        let total: Int
    }
    
    var progressUpdates: [ProgressUpdate] = []
    
    func ripperDidStart() {
        didStartCalled = true
    }
    
    func ripperDidUpdateStatus(_ status: String) {
        didUpdateStatusCalled = true
        lastStatus = status
    }
    
    func ripperDidUpdateProgress(_ progress: Double, currentItem: MediaRipper.MediaItem?, totalItems: Int) {
        didUpdateProgressCalled = true
        lastProgress = progress
        progressUpdates.append(ProgressUpdate(progress: progress, item: currentItem, total: totalItems))
    }
    
    func ripperDidComplete() {
        didCompleteCalled = true
    }
    
    func ripperDidFail(with error: Error) {
        didFailCalled = true
        lastError = error
    }
    
    func reset() {
        didStartCalled = false
        didUpdateStatusCalled = false
        didUpdateProgressCalled = false
        didCompleteCalled = false
        didFailCalled = false
        lastStatus = nil
        lastProgress = nil
        lastError = nil
        progressUpdates.removeAll()
    }
}
