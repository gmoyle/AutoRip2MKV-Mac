import Foundation

// MARK: - Blu-ray Ripping Implementation

extension MediaRipper {

    func performBluRayRipping(blurayPath: String, configuration: RippingConfiguration) throws {

        let maxRetries = 3
        var playlists: [BluRayPlaylist] = []
        var lastError: Error? = nil

        // Step 0: Analyze disc for quality optimization
        delegate?.ripperDidUpdateStatus("Analyzing disc quality...")
        let qualityAssessment: QualityAssessment
        do {
            qualityAssessment = try analyzeMedia(mediaPath: blurayPath, mediaType: .bluray)
        } catch {
            Logger.shared.logError(error, context: "Quality analysis failed; using default settings.")
            // Fallback: use default configuration
            qualityAssessment = QualityAssessment(
                resolution: .fullHD1080p,
                estimatedBitrate: 18000,
                contentType: .liveAction,
                complexityScore: 7.0,
                hdrPresent: false,
                audioTracks: [],
                recommendedCodec: configuration.videoCodec,
                recommendedCRF: configuration.quality.crf,
                recommendedBitrate: 18000,
                sceneChangeRate: nil,
                motionIntensity: nil,
                grainLevel: nil,
                animationScore: nil,
                subtitleComplexity: nil,
                audioComplexity: nil,
                hdrType: nil,
                immersiveAudio: nil
            )
        }

        // Step 1: Parse Blu-ray structure with retry
        delegate?.ripperDidUpdateStatus("Analyzing Blu-ray structure...")
        for attempt in 1...maxRetries {
            do {
                blurayParser = BluRayStructureParser(blurayPath: blurayPath)
                playlists = try blurayParser!.parseBluRayStructure()
                break
            } catch {
                lastError = error
                Logger.shared.logError(error, context: "Blu-ray structure parse failed (attempt \(attempt))")
                delegate?.ripperDidUpdateStatus("Structure parse failed (attempt \(attempt)). Retrying...")
                if attempt == maxRetries {
                    delegate?.ripperDidFail(with: error)
                    throw error
                }
            }
        }

        guard !playlists.isEmpty else {
            let error = MediaRipperError.noTitlesFound
            Logger.shared.logError(error, context: "No playlists found in Blu-ray")
            delegate?.ripperDidFail(with: error)
            throw error
        }

        // Step 2: Extract movie name and create organized directory
        delegate?.ripperDidUpdateStatus("Analyzing disc information...")
        let movieName = extractMovieName(from: blurayPath, mediaType: currentMediaType)
        let organizedOutputDirectory = createOrganizedOutputDirectory(
            baseDirectory: configuration.outputDirectory,
            mediaType: currentMediaType,
            movieName: movieName
        )

        // Create disc info file
        createDiscInfo(in: organizedOutputDirectory, mediaPath: blurayPath,
                      mediaType: currentMediaType, movieName: movieName)
        // Log quality report
        Logger.shared.log(MediaRipper.generateQualityReport(qualityAssessment), level: .info, category: .general)

        // Update configuration with recommended settings
        var optimizedConfig = configuration
        optimizedConfig = RippingConfiguration(
            outputDirectory: configuration.outputDirectory,
            selectedTitles: configuration.selectedTitles,
            videoCodec: qualityAssessment.recommendedCodec,
            audioCodec: configuration.audioCodec,
            quality: .high, // Use high for best CRF mapping
            includeSubtitles: configuration.includeSubtitles,
            includeChapters: configuration.includeChapters,
            mediaType: configuration.mediaType,
            batchMode: configuration.batchMode
        )
        // ...existing code...

        // Step 3: Extract cover art if available
        delegate?.ripperDidUpdateStatus("Extracting cover art...")
        extractCoverArt(from: blurayPath, to: organizedOutputDirectory)

        // Step 4: Initialize Blu-ray decryptor with retry
        delegate?.ripperDidUpdateStatus("Initializing Blu-ray AACS decryption...")
        for attempt in 1...maxRetries {
            do {
                blurayDecryptor = BluRayDecryptor(devicePath: blurayPath)
                try blurayDecryptor!.initializeDecryption()
                break
            } catch {
                lastError = error
                Logger.shared.logError(error, context: "Blu-ray decryption init failed (attempt \(attempt))")
                delegate?.ripperDidUpdateStatus("Decryption init failed (attempt \(attempt)). Retrying...")
                if attempt == maxRetries {
                    delegate?.ripperDidFail(with: error)
                    throw error
                }
            }
        }

        // Step 5: Determine which playlists to rip
        let playlistsToRip = filterPlaylistsToRip(playlists: playlists, selectedTitles: configuration.selectedTitles)
        delegate?.ripperDidUpdateProgress(0.0, currentItem: nil, totalItems: playlistsToRip.count)

        // Step 6: Rip each playlist to organized directory with error recovery
        for (index, playlist) in playlistsToRip.enumerated() {
            if shouldCancel {
                let error = MediaRipperError.cancelled
                Logger.shared.logError(error, context: "Ripping cancelled by user")
                delegate?.ripperDidFail(with: error)
                throw error
            }

            delegate?.ripperDidUpdateStatus(
                "Ripping Blu-ray playlist \(playlist.number) (\(playlist.formattedDuration))..."
            )
            var playlistSuccess = false
            for attempt in 1...maxRetries {
                do {
                    try ripBluRayPlaylist(
                        playlist, configuration: configuration, outputDirectory: organizedOutputDirectory,
                        playlistIndex: index, totalPlaylists: playlistsToRip.count
                    )
                    playlistSuccess = true
                    break
                } catch {
                    lastError = error
                    Logger.shared.logError(error, context: "Failed to rip playlist \(playlist.number) (attempt \(attempt))")
                    delegate?.ripperDidUpdateStatus("Ripping failed for playlist \(playlist.number) (attempt \(attempt)). Retrying...")
                    if attempt == maxRetries {
                        delegate?.ripperDidUpdateStatus("Skipping failed playlist \(playlist.number).")
                        // Optionally, continue with next playlist instead of failing all
                    }
                }
            }
            if !playlistSuccess {
                // Log and notify about skipped playlist
                Logger.shared.log("Skipped playlist \(playlist.number) after repeated failures.", level: .warning, category: .general)
            }
        }
        // All playlists processed
        delegate?.ripperDidUpdateStatus("Blu-ray ripping completed.")
    }

    private func ripBluRayPlaylist(
        _ playlist: BluRayPlaylist,
        configuration: RippingConfiguration,
        outputDirectory: String,
        playlistIndex: Int,
        totalPlaylists: Int
    ) throws {
        // Create intelligent output filename
        let playlistName = determinePlaylistName(
            playlist: playlist, playlistIndex: playlistIndex, totalPlaylists: totalPlaylists
        )
        let duration = playlist.formattedDuration.replacingOccurrences(of: ":", with: "-")
        let outputFileName = "\(playlistName)_\(duration).mkv"
        let outputPath = outputDirectory.appending("/\(outputFileName)")

        // Extract and decrypt playlist data
        let tempVideoFile = try extractAndDecryptBluRayPlaylist(playlist)

        // Convert to MKV
        try convertToMKV(
            inputFile: tempVideoFile,
            outputFile: outputPath,
            mediaItem: .blurayPlaylist(playlist),
            configuration: configuration,
            itemIndex: playlistIndex,
            totalItems: totalPlaylists
        )

        // Cleanup temp file
        try? FileManager.default.removeItem(atPath: tempVideoFile)
    }

    private func extractAndDecryptBluRayPlaylist(_ playlist: BluRayPlaylist) throws -> String {
        let tempDirectory = NSTemporaryDirectory()
        let tempFileName = "temp_bluray_playlist_\(playlist.number).m2ts"
        let tempFilePath = tempDirectory.appending(tempFileName)

        guard let outputHandle = FileHandle(forWritingAtPath: tempFilePath) ??
              createFileAndGetHandle(at: tempFilePath) else {
            throw MediaRipperError.fileCreationFailed
        }

        defer { outputHandle.closeFile() }

        var totalBytesRead: Int64 = 0
        let totalSize = Int64(playlist.totalSize)

        // Process each clip in the playlist
        for (clipIndex, clip) in playlist.clips.enumerated() {
            if shouldCancel {
                throw MediaRipperError.cancelled
            }

            delegate?.ripperDidUpdateStatus(
                "Processing clip \(clipIndex + 1)/\(playlist.clips.count) in playlist \(playlist.number)..."
            )

            // Read and decrypt clip data
            let clipData = try extractAndDecryptBluRayClip(clip)
            outputHandle.write(clipData)

            totalBytesRead += Int64(clipData.count)

            // Update progress
            let progress = Double(totalBytesRead) / Double(totalSize)
            delegate?.ripperDidUpdateProgress(
                progress * 0.5, currentItem: .blurayPlaylist(playlist), totalItems: 1
            ) // 50% for extraction
        }

        return tempFilePath
    }

    private func extractAndDecryptBluRayClip(_ clip: BluRayClip) throws -> Data {
        // Read the .m2ts file
        let clipPath = blurayParser?.blurayPath.appending("/BDMV/STREAM/\(clip.filename)")

        guard let clipPath = clipPath,
              let clipData = FileManager.default.contents(atPath: clipPath) else {
            throw MediaRipperError.fileNotFound
        }

        // Decrypt the data if needed
        if let decryptor = blurayDecryptor {
            return try decryptor.decryptClip(data: clipData, clip: clip)
        } else {
            // If no decryption is needed (e.g., unprotected disc)
            return clipData
        }
    }

    private func filterPlaylistsToRip(playlists: [BluRayPlaylist], selectedTitles: [Int]) -> [BluRayPlaylist] {
        if selectedTitles.isEmpty {
            // Use intelligent filtering when no playlists explicitly selected
            if SettingsManager.shared.intelligentTitleSelection {
                let analyzer = TitleAnalyzer()
                let rules = SettingsManager.shared.getTitleFilteringRules()
                let filtered = analyzer.filterBluRayPlaylists(playlists, rules: rules)
                
                Logger.shared.log(
                    "Intelligent playlist filtering: \(playlists.count) playlists → \(filtered.count) selected",
                    level: .info,
                    category: .general
                )
                
                return filtered
            } else {
                // Fallback to basic duration filter
                return playlists.filter { $0.duration >= 60.0 }
            }
        } else {
            // Return only explicitly selected playlists
            return playlists.filter { selectedTitles.contains($0.number) }
        }
    }

    /// Determine appropriate playlist name based on content and position
    private func determinePlaylistName(playlist: BluRayPlaylist, playlistIndex: Int, totalPlaylists: Int) -> String {
        // Use intelligent classification if enabled
        if SettingsManager.shared.intelligentTitleSelection {
            let analyzer = TitleAnalyzer()
            let rules = SettingsManager.shared.getTitleFilteringRules()
            let scores = analyzer.analyzeBluRayPlaylists([playlist], rules: rules)
            
            if let score = scores.first {
                switch score.classification {
                case .mainFeature:
                    return "Main_Movie"
                case .extendedEdition:
                    return "Extended_Edition"
                case .bonusFeature:
                    return "Bonus_Feature_\(String(format: "%05d", playlist.number))"
                case .trailer:
                    return "Trailer_\(String(format: "%05d", playlist.number))"
                case .menu:
                    return "Menu_\(String(format: "%05d", playlist.number))"
                case .duplicate:
                    return "Duplicate_\(String(format: "%05d", playlist.number))"
                case .unknown:
                    return "Playlist_\(String(format: "%05d", playlist.number))"
                }
            }
        }
        
        // Fallback to legacy heuristic classification
        let isMainPlaylist = (playlistIndex == 0 && playlist.duration > 3600) || // First playlist over 1 hour
                            (playlist.duration >= 5400) || // Any playlist over 90 minutes
                            (totalPlaylists == 1) // Only one playlist

        if isMainPlaylist {
            return "Main_Movie"
        } else if playlist.duration >= 3600 { // 60+ minutes
            return "Feature_\(String(format: "%05d", playlist.number))"
        } else if playlist.duration >= 1800 { // 30+ minutes
            return "Extended_Content_\(String(format: "%05d", playlist.number))"
        } else if playlist.duration >= 300 { // 5+ minutes
            return "Bonus_Content_\(String(format: "%05d", playlist.number))"
        } else {
            return "Short_\(String(format: "%05d", playlist.number))"
        }
    }
}
