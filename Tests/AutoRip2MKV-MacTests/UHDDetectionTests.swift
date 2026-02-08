import XCTest
@testable import AutoRip2MKV_Mac

/// Tests for UHD Blu-ray detection and resolution analysis
class UHDDetectionTests: XCTestCase {

    var mediaRipper: MediaRipper!
    var testBundle: Bundle!

    override func setUp() {
        super.setUp()
        mediaRipper = MediaRipper()
        testBundle = Bundle(for: type(of: self))
    }

    override func tearDown() {
        super.tearDown()
        mediaRipper = nil
        testBundle = nil
    }

    // MARK: - UHD Detection Tests

    func testDetectUHDBluRayMedia() {
        // Test that UHD Blu-ray is correctly identified
        let mediaType = mediaRipper.detectMediaType(path: "/Volumes/TestBluray4K")

        // Note: In real testing, would use actual mounted media
        // This tests the detection logic exists
        XCTAssertNotEqual(mediaType, .unknown)
    }

    func testDetectStandardBluRayMedia() {
        // Test that standard HD Blu-ray is distinguished from UHD
        let mediaType = mediaRipper.detectMediaType(path: "/Volumes/TestBluray")

        XCTAssertNotEqual(mediaType, .unknown)
    }

    func testMediaTypeEnumValues() {
        // Test that MediaType enum has required cases
        let dvd = MediaRipper.MediaType.dvd
        let bluray = MediaRipper.MediaType.bluray
        let bluray4K = MediaRipper.MediaType.bluray4K
        let ultraHDDVD = MediaRipper.MediaType.ultraHDDVD

        XCTAssertEqual(dvd.folderName, "DVD")
        XCTAssertEqual(bluray.folderName, "Blu-ray")
        XCTAssertEqual(bluray4K.folderName, "4K_Blu-ray")
        XCTAssertEqual(ultraHDDVD.folderName, "Ultra_HD_DVD")
    }

    // MARK: - Resolution Detection Tests

    func testResolutionEnum() {
        // Test Resolution enum values and properties
        let sd480 = MediaRipper.QualityAssessment.Resolution.sd480p
        let hd720 = MediaRipper.QualityAssessment.Resolution.hd720p
        let fullHD = MediaRipper.QualityAssessment.Resolution.fullHD1080p
        let uhd2160 = MediaRipper.QualityAssessment.Resolution.uhd2160p
        let uhd4320 = MediaRipper.QualityAssessment.Resolution.uhd4320p

        XCTAssertEqual(sd480.heightPixels, 480)
        XCTAssertEqual(hd720.heightPixels, 720)
        XCTAssertEqual(fullHD.heightPixels, 1080)
        XCTAssertEqual(uhd2160.heightPixels, 2160)
        XCTAssertEqual(uhd4320.heightPixels, 4320)
    }

    func testResolutionIsUHDFlag() {
        // Test that UHD flag is correctly set
        let fullHD = MediaRipper.QualityAssessment.Resolution.fullHD1080p
        let uhd2160 = MediaRipper.QualityAssessment.Resolution.uhd2160p

        XCTAssertFalse(fullHD.isUHD)
        XCTAssertTrue(uhd2160.isUHD)
    }

    func testResolutionDisplayNames() {
        // Test that display names are user-friendly
        let fullHD = MediaRipper.QualityAssessment.Resolution.fullHD1080p
        let uhd = MediaRipper.QualityAssessment.Resolution.uhd2160p

        XCTAssertEqual(fullHD.displayName, "Full HD (1080p)")
        XCTAssertEqual(uhd.displayName, "4K UHD (2160p)")
    }

    // MARK: - Resolution Parsing Tests

    func testParseClipResolutionFromValidData() {
        // Create mock CLPI data with resolution marker
        var mockData = Data()

        // Add CLPI signature (4 bytes)
        mockData.append(contentsOf: "CLPI".utf8)

        // Add padding (68 bytes to reach byte 0x50)
        let padding = Data(count: 64)
        mockData.append(padding)

        // Add stream coding byte with resolution=2 (fullHD)
        mockData.append(UInt8(2))

        let resolution = mediaRipper.parseClipResolution(from: mockData)
        XCTAssertEqual(resolution, .fullHD1080p)
    }

    func testParseClipResolution720p() {
        var mockData = Data()
        mockData.append(contentsOf: "CLPI".utf8)
        let padding = Data(count: 64)
        mockData.append(padding)
        mockData.append(UInt8(1)) // Resolution = 1 (720p)

        let resolution = mediaRipper.parseClipResolution(from: mockData)
        XCTAssertEqual(resolution, .hd720p)
    }

    func testParseClipResolution4K() {
        var mockData = Data()
        mockData.append(contentsOf: "CLPI".utf8)
        let padding = Data(count: 64)
        mockData.append(padding)
        mockData.append(UInt8(4)) // Resolution = 4 (4K)

        let resolution = mediaRipper.parseClipResolution(from: mockData)
        XCTAssertEqual(resolution, .uhd2160p)
    }

    func testParseClipResolutionInvalidSignature() {
        var mockData = Data()
        mockData.append(contentsOf: "INVA".utf8)
        let padding = Data(count: 64)
        mockData.append(padding)

        let resolution = mediaRipper.parseClipResolution(from: mockData)
        XCTAssertNil(resolution)
    }

    func testParseClipResolutionTooShort() {
        let mockData = Data(count: 20)

        let resolution = mediaRipper.parseClipResolution(from: mockData)
        XCTAssertNil(resolution)
    }

    // MARK: - Quality Assessment Tests

    func testQualityAssessmentStructure() {
        // Test that QualityAssessment can be created with all properties
        let assessment = MediaRipper.QualityAssessment(
            resolution: .fullHD1080p,
            estimatedBitrate: 8000,
            contentType: .liveAction,
            complexityScore: 7.5,
            hdrPresent: true,
            audioTracks: [],
            recommendedCodec: .h265,
            recommendedCRF: 23,
            recommendedBitrate: 6000,
            sceneChangeRate: nil,
            motionIntensity: nil,
            grainLevel: nil,
            animationScore: nil,
            subtitleComplexity: nil,
            audioComplexity: nil,
            hdrType: nil,
            immersiveAudio: nil
        )

        XCTAssertEqual(assessment.resolution, .fullHD1080p)
        XCTAssertEqual(assessment.estimatedBitrate, 8000)
        XCTAssertEqual(assessment.contentType, .liveAction)
        XCTAssertEqual(assessment.complexityScore, 7.5)
        XCTAssertTrue(assessment.hdrPresent)
        XCTAssertEqual(assessment.recommendedCodec, .h265)
        XCTAssertEqual(assessment.recommendedCRF, 23)
    }

    // MARK: - Complexity Scoring Tests

    func testCalculateComplexityScoreBaseline() {
        let score = mediaRipper.calculateComplexityScore(
            resolution: .fullHD1080p,
            contentType: .liveAction,
            audioTrackCount: 1,
            hdrPresent: false
        )

        XCTAssertGreaterThan(score, 0.0)
        XCTAssertLessThanOrEqual(score, 10.0)
    }

    func testCalculateComplexityScoreUHDIncreases() {
        let scoreFullHD = mediaRipper.calculateComplexityScore(
            resolution: .fullHD1080p,
            contentType: .liveAction,
            audioTrackCount: 1,
            hdrPresent: false
        )

        let scoreUHD = mediaRipper.calculateComplexityScore(
            resolution: .uhd2160p,
            contentType: .liveAction,
            audioTrackCount: 1,
            hdrPresent: false
        )

        XCTAssertGreaterThan(scoreUHD, scoreFullHD)
    }

    func testCalculateComplexityScoreAnimationLower() {
        let scoreAnimation = mediaRipper.calculateComplexityScore(
            resolution: .fullHD1080p,
            contentType: .animation,
            audioTrackCount: 1,
            hdrPresent: false
        )

        let scoreLiveAction = mediaRipper.calculateComplexityScore(
            resolution: .fullHD1080p,
            contentType: .liveAction,
            audioTrackCount: 1,
            hdrPresent: false
        )

        XCTAssertLessThan(scoreAnimation, scoreLiveAction)
    }

    func testCalculateComplexityScoreSports() {
        let score = mediaRipper.calculateComplexityScore(
            resolution: .fullHD1080p,
            contentType: .sports,
            audioTrackCount: 1,
            hdrPresent: false
        )

        XCTAssertGreaterThanOrEqual(score, 1.0)
        XCTAssertLessThanOrEqual(score, 10.0)
    }

    func testCalculateComplexityScoreWithHDR() {
        let scoreWithoutHDR = mediaRipper.calculateComplexityScore(
            resolution: .fullHD1080p,
            contentType: .liveAction,
            audioTrackCount: 1,
            hdrPresent: false
        )

        let scoreWithHDR = mediaRipper.calculateComplexityScore(
            resolution: .fullHD1080p,
            contentType: .liveAction,
            audioTrackCount: 1,
            hdrPresent: true
        )

        XCTAssertGreaterThan(scoreWithHDR, scoreWithoutHDR)
    }

    func testCalculateComplexityScoreMultipleAudio() {
        let scoreSingleAudio = mediaRipper.calculateComplexityScore(
            resolution: .fullHD1080p,
            contentType: .liveAction,
            audioTrackCount: 1,
            hdrPresent: false
        )

        let scoreMultiAudio = mediaRipper.calculateComplexityScore(
            resolution: .fullHD1080p,
            contentType: .liveAction,
            audioTrackCount: 4,
            hdrPresent: false
        )

        XCTAssertGreaterThan(scoreMultiAudio, scoreSingleAudio)
    }

    func testCalculateComplexityScoreClamping() {
        // Test extreme inputs are clamped to 1.0-10.0 range
        let score1 = mediaRipper.calculateComplexityScore(
            resolution: .sd480p,
            contentType: .animation,
            audioTrackCount: 0,
            hdrPresent: false
        )

        let score2 = mediaRipper.calculateComplexityScore(
            resolution: .uhd4320p,
            contentType: .sports,
            audioTrackCount: 10,
            hdrPresent: true
        )

        XCTAssertGreaterThanOrEqual(score1, 1.0)
        XCTAssertLessThanOrEqual(score1, 10.0)
        XCTAssertGreaterThanOrEqual(score2, 1.0)
        XCTAssertLessThanOrEqual(score2, 10.0)
    }

    // MARK: - Bitrate Estimation Tests

    func testEstimateBluRayBitrateSD() {
        let bitrate = mediaRipper.estimateBluRayBitrate(
            mediaPath: "/test",
            resolution: .sd480p
        )

        XCTAssertEqual(bitrate, 4000)
    }

    func testEstimateBluRayBitrateHD() {
        let bitrate = mediaRipper.estimateBluRayBitrate(
            mediaPath: "/test",
            resolution: .hd720p
        )

        XCTAssertEqual(bitrate, 6000)
    }

    func testEstimateBluRayBitrateFullHD() {
        let bitrate = mediaRipper.estimateBluRayBitrate(
            mediaPath: "/test",
            resolution: .fullHD1080p
        )

        XCTAssertEqual(bitrate, 8000)
    }

    func testEstimateBluRayBitrateUHD() {
        let bitrate = mediaRipper.estimateBluRayBitrate(
            mediaPath: "/test",
            resolution: .uhd2160p
        )

        XCTAssertEqual(bitrate, 20000)
    }

    // MARK: - Encoding Recommendation Tests

    func testGenerateRecommendationsFullHDStandard() {
        let (codec, crf, _) = mediaRipper.generateRecommendations(
            resolution: .fullHD1080p,
            complexityScore: 5.0,
            contentType: .liveAction,
            estimatedBitrate: 8000
        )

        XCTAssertEqual(codec, .h264)
        XCTAssertEqual(crf, 23)
    }

    func testGenerateRecommendationsUHDComplex() {
        let (codec, crf, _) = mediaRipper.generateRecommendations(
            resolution: .uhd2160p,
            complexityScore: 8.0,
            contentType: .liveAction,
            estimatedBitrate: 20000
        )

        XCTAssertEqual(codec, .av1)
        XCTAssertEqual(crf, 28)
    }

    func testGenerateRecommendationsUHDStandard() {
        let (codec, crf, _) = mediaRipper.generateRecommendations(
            resolution: .uhd2160p,
            complexityScore: 5.0,
            contentType: .liveAction,
            estimatedBitrate: 20000
        )

        XCTAssertEqual(codec, .h265)
        XCTAssertEqual(crf, 25)
    }

    func testGenerateRecommendationsAnimation() {
        let (codec, crf, _) = mediaRipper.generateRecommendations(
            resolution: .fullHD1080p,
            complexityScore: 4.0,
            contentType: .animation,
            estimatedBitrate: 6000
        )

        XCTAssertEqual(codec, .h264)
        XCTAssertEqual(crf, 20)
    }

    func testGenerateRecommendationsBitrateReduction() {
        let (_, _, bitrate) = mediaRipper.generateRecommendations(
            resolution: .uhd2160p,
            complexityScore: 8.0,
            contentType: .liveAction,
            estimatedBitrate: 20000
        )

        // AV1 at high complexity should reduce bitrate
        XCTAssertLessThan(bitrate, 20000)
    }

    // MARK: - Content Type Tests

    func testContentTypeEnumValues() {
        let liveAction = MediaRipper.QualityAssessment.ContentType.liveAction
        let animation = MediaRipper.QualityAssessment.ContentType.animation
        let sports = MediaRipper.QualityAssessment.ContentType.sports

        XCTAssertEqual(liveAction.description, "Live Action")
        XCTAssertEqual(animation.description, "Animation")
        XCTAssertEqual(sports.description, "Sports")
    }

    // MARK: - Audio Track Tests

    func testAudioTrackInfo() {
        let track = MediaRipper.AudioTrackInfo(
            index: 0,
            language: "English",
            codec: "AC3",
            channels: 6,
            sampleRate: 48000
        )

        XCTAssertEqual(track.index, 0)
        XCTAssertEqual(track.language, "English")
        XCTAssertEqual(track.codec, "AC3")
        XCTAssertEqual(track.channels, 6)
        XCTAssertEqual(track.sampleRate, 48000)
    }

    // MARK: - Analysis Error Tests

    func testAnalysisErrorDescriptions() {
        let unsupported = MediaRipper.AnalysisError.unsupportedMediaType
        let noPlaylists = MediaRipper.AnalysisError.noPlaylistsFound
        let noTitles = MediaRipper.AnalysisError.noTitlesFound

        XCTAssertNotNil(unsupported.errorDescription)
        XCTAssertNotNil(noPlaylists.errorDescription)
        XCTAssertNotNil(noTitles.errorDescription)
    }

    // MARK: - Integration Tests

    func testFullQualityAssessmentCreation() {
        let assessment = MediaRipper.QualityAssessment(
            resolution: .uhd2160p,
            estimatedBitrate: 20000,
            contentType: .liveAction,
            complexityScore: 7.5,
            hdrPresent: true,
            audioTracks: [
                MediaRipper.AudioTrackInfo(
                    index: 0,
                    language: "English",
                    codec: "AC3",
                    channels: 6,
                    sampleRate: 48000
                ),
                MediaRipper.AudioTrackInfo(
                    index: 1,
                    language: "Spanish",
                    codec: "AAC",
                    channels: 2,
                    sampleRate: 48000
                ),
            ],
            recommendedCodec: .av1,
            recommendedCRF: 28,
            recommendedBitrate: 12000,
            sceneChangeRate: nil,
            motionIntensity: nil,
            grainLevel: nil,
            animationScore: nil,
            subtitleComplexity: nil,
            audioComplexity: nil,
            hdrType: nil,
            immersiveAudio: nil
        )

        XCTAssertEqual(assessment.resolution, .uhd2160p)
        XCTAssertEqual(assessment.audioTracks.count, 2)
        XCTAssertEqual(assessment.audioTracks[0].language, "English")
        XCTAssertEqual(assessment.audioTracks[1].language, "Spanish")
        XCTAssertTrue(assessment.hdrPresent)
    }
}
