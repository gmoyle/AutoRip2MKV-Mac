import Foundation
import AVFoundation

/// Extension to MediaRipper for advanced disc analysis and quality assessment
extension MediaRipper {

    /// Represents the quality assessment of media content
    struct QualityAssessment {
        let resolution: Resolution
        let estimatedBitrate: Int // in kbps
        let contentType: ContentType
        let complexityScore: Double // 1.0-10.0
        let hdrPresent: Bool
        let audioTracks: [AudioTrackInfo]
        let recommendedCodec: RippingConfiguration.VideoCodec
        let recommendedCRF: Int
        let recommendedBitrate: Int // in kbps

        enum Resolution {
            case unknown
            case sd480p  // 720×480
            case sd576p  // 720×576
            case hd720p  // 1280×720
            case fullHD1080p  // 1920×1080
            case uhd2160p  // 3840×2160
            case uhd4320p  // 7680×4320

            var displayName: String {
                switch self {
                case .unknown: return "Unknown"
                case .sd480p: return "SD (480p)"
                case .sd576p: return "SD (576p)"
                case .hd720p: return "HD (720p)"
                case .fullHD1080p: return "Full HD (1080p)"
                case .uhd2160p: return "4K UHD (2160p)"
                case .uhd4320p: return "8K UHD (4320p)"
                }
            }

            var heightPixels: Int {
                switch self {
                case .unknown: return 0
                case .sd480p: return 480
                case .sd576p: return 576
                case .hd720p: return 720
                case .fullHD1080p: return 1080
                case .uhd2160p: return 2160
                case .uhd4320p: return 4320
                }
            }

            var isUHD: Bool {
                return self == .uhd2160p || self == .uhd4320p
            }
        }

        enum ContentType {
            case liveAction
            case animation
            case mixed
            case sports
            case unknown

            var description: String {
                switch self {
                case .liveAction: return "Live Action"
                case .animation: return "Animation"
                case .mixed: return "Mixed"
                case .sports: return "Sports"
                case .unknown: return "Unknown"
                }
            }
        }
    }

    /// Information about an audio track
    struct AudioTrackInfo {
        let index: Int
        let language: String?
        let codec: String?
        let channels: Int?
        let sampleRate: Int? // in Hz
    }

    /// Analyzes a disc and provides quality assessment and recommendations
    /// - Parameters:
    ///   - mediaPath: Path to mounted media (BDMV folder for Blu-ray, VIDEO_TS for DVD, HD_DVD for HD DVD)
    ///   - mediaType: Type of media being analyzed
    /// - Returns: QualityAssessment containing analysis results and recommendations
    func analyzeMedia(mediaPath: String, mediaType: MediaType = .unknown) throws -> QualityAssessment {
        let detectedType = mediaType == .unknown ? detectMediaType(path: mediaPath) : mediaType

        switch detectedType {
        case .bluray, .bluray4K:
            return try analyzeBluRayMedia(mediaPath)
        case .dvd, .ultraHDDVD:
            return try analyzeDVDMedia(mediaPath, isUHD: detectedType == .ultraHDDVD)
        case .hddvd:
            return try analyzeHDDVDMedia(mediaPath)
        case .unknown:
            throw AnalysisError.unsupportedMediaType
        }
    }

    /// Analyzes HD DVD media structure and content
    private func analyzeHDDVDMedia(_ mediaPath: String) throws -> QualityAssessment {
        let parser = HDDVDStructureParser()
        let structure = try parser.parseStructure(at: mediaPath)

        guard !structure.titles.isEmpty else {
            throw AnalysisError.noTitlesFound
        }
        // Select main title by longest duration
        let mainTitle = structure.titles.max(by: { $0.durationSeconds < $1.durationSeconds })!

        // Map HDDVDResolution to QualityAssessment.Resolution
        let resolution: QualityAssessment.Resolution
        switch mainTitle.resolution {
        case .sd480p: resolution = .sd480p
        case .hd720p: resolution = .hd720p
        case .fullHD1080p: resolution = .fullHD1080p
        case .unknown: resolution = .unknown
        }

        // Map HDDVDAudioTrack to AudioTrackInfo
        let audioTracks: [AudioTrackInfo] = mainTitle.audioTracks.map {
            AudioTrackInfo(
                index: $0.index,
                language: $0.language,
                codec: $0.codec,
                channels: $0.channels,
                sampleRate: $0.sampleRate
            )
        }

        // Log subtitle tracks and menu set
        let subtitleInfo = mainTitle.subtitleTracks.map { "\($0.language) [\($0.format)]" }.joined(separator: ", ")
        Logger.shared.log("Subtitle Tracks: \(subtitleInfo)", level: .info, category: .general)
        if let menuSet = mainTitle.menuSet {
            Logger.shared.log("Menu Set: \(menuSet)", level: .info, category: .general)
        }
        Logger.shared.log("Estimated Bitrate: \(mainTitle.estimatedBitrate) kbps", level: .info, category: .general)
        Logger.shared.log("Audio Tracks: \(mainTitle.audioTracks.count)", level: .info, category: .general)

        // HD DVD content type: infer from title name and codec
        let contentType: QualityAssessment.ContentType
        if mainTitle.name.lowercased().contains("documentary") {
            contentType = .mixed
        } else if mainTitle.videoCodec == "MPEG-2" {
            contentType = .animation
        } else {
            contentType = .liveAction
        }

        // Complexity score (adjust for HD DVD)
        let complexityScore = calculateComplexityScore(
            resolution: resolution,
            contentType: contentType,
            audioTrackCount: audioTracks.count,
            hdrPresent: false
        )

        // Bitrate estimation (use Blu-ray logic for HD DVD)
        var estimatedBitrate = estimateBluRayBitrate(mediaPath: mediaPath, resolution: resolution)
        // Adjust bitrate for dual layer
        if structure.isDualLayer {
            estimatedBitrate += 2000
        }

        // Recommendations
        let (recommendedCodec, recommendedCRF, recommendedBitrate) = generateRecommendations(
            resolution: resolution,
            complexityScore: complexityScore,
            contentType: contentType,
            estimatedBitrate: estimatedBitrate
        )

        // Optionally log volume label for reporting
        Logger.shared.log("HD DVD Volume: \(structure.volumeLabel), Main Title: \(mainTitle.name)", level: .info, category: .general)

        return QualityAssessment(
            resolution: resolution,
            estimatedBitrate: estimatedBitrate,
            contentType: contentType,
            complexityScore: complexityScore,
            hdrPresent: false,
            audioTracks: audioTracks,
            recommendedCodec: recommendedCodec,
            recommendedCRF: recommendedCRF,
            recommendedBitrate: recommendedBitrate
        )
    }

    // MARK: - Blu-ray Analysis

    /// Analyzes Blu-ray media structure and content
    private func analyzeBluRayMedia(_ mediaPath: String) throws -> QualityAssessment {
        let parser = BluRayStructureParser(blurayPath: mediaPath)

        _ = try parser.parseBluRayStructure()

        guard let mainPlaylist = parser.getMainPlaylist() else {
            throw AnalysisError.noPlaylistsFound
        }

        // Determine resolution from clip information
        let resolution = try detectBluRayResolution(mediaPath: mediaPath, parser: parser)

        // Detect HDR metadata
        let hdrPresent = try detectHDRMetadata(mediaPath: mediaPath)

        // Extract audio track information
        let audioTracks = extractBluRayAudioTracks(from: mainPlaylist)

        // Analyze content characteristics
        let contentType = try analyzeBluRayContentType(mediaPath: mediaPath, playlist: mainPlaylist)

        // Calculate complexity score based on content characteristics
        let complexityScore = calculateComplexityScore(
            resolution: resolution,
            contentType: contentType,
            audioTrackCount: audioTracks.count,
            hdrPresent: hdrPresent
        )

        // Estimate bitrate from source
        let estimatedBitrate = estimateBluRayBitrate(mediaPath: mediaPath, resolution: resolution)

        // Generate recommendations
        let (recommendedCodec, recommendedCRF, recommendedBitrate) = generateRecommendations(
            resolution: resolution,
            complexityScore: complexityScore,
            contentType: contentType,
            estimatedBitrate: estimatedBitrate
        )

        return QualityAssessment(
            resolution: resolution,
            estimatedBitrate: estimatedBitrate,
            contentType: contentType,
            complexityScore: complexityScore,
            hdrPresent: hdrPresent,
            audioTracks: audioTracks,
            recommendedCodec: recommendedCodec,
            recommendedCRF: recommendedCRF,
            recommendedBitrate: recommendedBitrate
        )
    }

    /// Detects the resolution of Blu-ray content
    private func detectBluRayResolution(mediaPath: String, parser: BluRayStructureParser) throws -> QualityAssessment.Resolution {
        // Check for UHD indicator files in BDMV structure
        let bdmvPath = mediaPath.appending("/BDMV")
        let uhdIndicatorPath = bdmvPath.appending("/auxData")

        let isUHD = FileManager.default.fileExists(atPath: uhdIndicatorPath)

        // Parse clip information for detailed resolution
        let clipinfPath = bdmvPath.appending("/CLIPINF")

        guard let clipFiles = try? FileManager.default.contentsOfDirectory(atPath: clipinfPath) else {
            // Fallback: if UHD indicators present, assume 4K
            return isUHD ? .uhd2160p : .fullHD1080p
        }

        // Analyze first clip file for resolution markers
        for clipFile in clipFiles where clipFile.hasSuffix(".clpi") {
            let filePath = clipinfPath.appending("/\(clipFile)")

            if let data = FileManager.default.contents(atPath: filePath) {
                if let resolution = parseClipResolution(from: data) {
                    return resolution
                }
            }
        }

        // Fallback based on UHD indicators
        return isUHD ? .uhd2160p : .fullHD1080p
    }

    /// Parses resolution from clip information file data
    func parseClipResolution(from data: Data) -> QualityAssessment.Resolution? {
        // CLPI format: look for stream coding info
        // Bytes 0-3: signature "CLPI"
        guard data.count >= 8 else { return nil }

        let signature = String(data: data.subdata(in: 0..<4), encoding: .ascii) ?? ""
        guard signature == "CLPI" else { return nil }

        // Stream coding info contains resolution info
        // This is a simplified parser - real implementation would be more detailed
        if data.count > 0x50 {
            let streamCodingByte = data[0x50]

            // Parse video coding type (bits 4-7 = video codec, bits 0-3 = resolution)
            let resolution = streamCodingByte & 0x0F

            switch resolution {
            case 1: return .hd720p
            case 2: return .fullHD1080p
            case 4: return .uhd2160p
            default: return .fullHD1080p
            }
        }

        return nil
    }

    /// Detects HDR metadata in Blu-ray content
    private func detectHDRMetadata(mediaPath: String) throws -> Bool {
        let bdmvPath = mediaPath.appending("/BDMV")
        let clipinfPath = bdmvPath.appending("/CLIPINF")

        guard let clipFiles = try? FileManager.default.contentsOfDirectory(atPath: clipinfPath) else {
            return false
        }

        for clipFile in clipFiles where clipFile.hasSuffix(".clpi") {
            let filePath = clipinfPath.appending("/\(clipFile)")

            if let data = FileManager.default.contents(atPath: filePath) {
                // Check for HDR metadata in stream coding info
                if data.count > 0x60 {
                    let hdrByte = data[0x60]

                    // Bits indicate HDR presence (simplified check)
                    if (hdrByte & 0x80) != 0 {
                        return true
                    }
                }
            }
        }

        return false
    }

    /// Extracts audio track information from Blu-ray playlist
    private func extractBluRayAudioTracks(from playlist: BluRayPlaylist) -> [AudioTrackInfo] {
        // Note: This is a simplified implementation
        // In a full implementation, would parse detailed MPLS structure
        var tracks: [AudioTrackInfo] = []

        // Extract from playlist clip stream info
        var trackIndex = 0
        for _ in playlist.clips {
            let track = AudioTrackInfo(
                index: trackIndex,
                language: nil,
                codec: "AC3",
                channels: 6,
                sampleRate: 48000
            )
            tracks.append(track)
            trackIndex += 1
        }

        return tracks
    }

    /// Analyzes content type from Blu-ray media characteristics
    private func analyzeBluRayContentType(mediaPath: String, playlist: BluRayPlaylist) throws -> QualityAssessment.ContentType {
        // Simplified content type detection based on playlist characteristics
        // In a full implementation, would analyze actual video frames

        if playlist.duration > 3600 { // > 1 hour
            return .liveAction
        }

        // Could analyze naming conventions, metadata, etc.
        return .unknown
    }

    // MARK: - DVD Analysis

    /// Analyzes DVD media
    private func analyzeDVDMedia(_ mediaPath: String, isUHD: Bool) throws -> QualityAssessment {
        let parser = DVDStructureParser(dvdPath: mediaPath)
        let titles = try parser.parseDVDStructure()

        guard !titles.isEmpty else {
            throw AnalysisError.noTitlesFound
        }

        // DVD resolution detection
        let resolution: QualityAssessment.Resolution = isUHD ? .uhd2160p : .fullHD1080p

        // DVD typically has 1-2 audio tracks with standard audio properties
        let audioTracks = [
            AudioTrackInfo(index: 0, language: "English", codec: "AC3", channels: 2, sampleRate: 48000),
        ]

        let contentType = QualityAssessment.ContentType.liveAction
        let complexityScore = 6.0 // Average for DVD content

        // DVD bitrate estimation
        let estimatedBitrate = isUHD ? 8000 : 6000 // kbps

        let (recommendedCodec, recommendedCRF, recommendedBitrate) = generateRecommendations(
            resolution: resolution,
            complexityScore: complexityScore,
            contentType: contentType,
            estimatedBitrate: estimatedBitrate
        )

        return QualityAssessment(
            resolution: resolution,
            estimatedBitrate: estimatedBitrate,
            contentType: contentType,
            complexityScore: complexityScore,
            hdrPresent: false,
            audioTracks: audioTracks,
            recommendedCodec: recommendedCodec,
            recommendedCRF: recommendedCRF,
            recommendedBitrate: recommendedBitrate
        )
    }

    // MARK: - Analysis Helpers

    /// Calculates complexity score based on content characteristics
    func calculateComplexityScore(
        resolution: QualityAssessment.Resolution,
        contentType: QualityAssessment.ContentType,
        audioTrackCount: Int,
        hdrPresent: Bool
    ) -> Double {
        var score: Double = 5.0 // Base score

        // Resolution factor
        switch resolution {
        case .sd480p, .sd576p: score -= 1.5
        case .hd720p: score -= 0.5
        case .fullHD1080p: score += 0.0
        case .uhd2160p: score += 1.5
        case .uhd4320p: score += 3.0
        case .unknown: score += 0.0
        }

        // Content type factor
        switch contentType {
        case .animation: score -= 1.0 // Animation is easier to compress
        case .liveAction: score += 0.5
        case .sports: score += 1.0 // Sports have high motion
        case .mixed: score += 0.0
        case .unknown: score += 0.0
        }

        // Audio complexity
        score += Double(audioTrackCount) * 0.2

        // HDR complexity
        if hdrPresent {
            score += 0.5
        }

        // Clamp to 1.0-10.0 range
        return max(1.0, min(10.0, score))
    }

    /// Estimates bitrate of source content
    func estimateBluRayBitrate(mediaPath: String, resolution: QualityAssessment.Resolution) -> Int {
        // Simplified bitrate estimation based on resolution
        switch resolution {
        case .sd480p, .sd576p: return 4000
        case .hd720p: return 6000
        case .fullHD1080p: return 8000
        case .uhd2160p: return 20000
        case .uhd4320p: return 40000
        case .unknown: return 8000
        }
    }

    /// Generates encoding recommendations based on analysis
    func generateRecommendations(
        resolution: QualityAssessment.Resolution,
        complexityScore: Double,
        contentType: QualityAssessment.ContentType,
        estimatedBitrate: Int
    ) -> (codec: RippingConfiguration.VideoCodec, crf: Int, bitrate: Int) {
        var recommendedCodec: RippingConfiguration.VideoCodec = .h264
        var recommendedCRF: Int = 23
        var recommendedBitrate: Int = estimatedBitrate

        // Codec recommendation based on resolution and complexity
        if resolution.isUHD {
            // UHD content benefits from H.265 or AV1
            if complexityScore > 7.0 {
                recommendedCodec = .av1 // AV1 for complex high-res content
                recommendedCRF = 28
                recommendedBitrate = Int(Double(estimatedBitrate) * 0.6)
            } else {
                recommendedCodec = .h265 // H.265 for standard UHD
                recommendedCRF = 25
                recommendedBitrate = Int(Double(estimatedBitrate) * 0.7)
            }
        } else {
            // Standard content
            if contentType == .animation {
                recommendedCodec = .h264 // Animation works well with H.264
                recommendedCRF = 20
            } else if complexityScore > 7.0 {
                recommendedCodec = .h265 // H.265 for complex live action
                recommendedCRF = 24
            } else {
                recommendedCodec = .h264 // H.264 for standard content
                recommendedCRF = 23
            }
        }

        return (recommendedCodec, recommendedCRF, recommendedBitrate)
    }

    // MARK: - Error Types

    enum AnalysisError: LocalizedError {
        case unsupportedMediaType
        case noPlaylistsFound
        case noTitlesFound
        case analysisTimeout
        case invalidMediaPath

        var errorDescription: String? {
            switch self {
            case .unsupportedMediaType:
                return "The media type is not supported for analysis"
            case .noPlaylistsFound:
                return "No playlists found in Blu-ray media"
            case .noTitlesFound:
                return "No titles found in DVD media"
            case .analysisTimeout:
                return "Media analysis took too long and was cancelled"
            case .invalidMediaPath:
                return "Invalid media path provided for analysis"
            }
        }
    }
}
