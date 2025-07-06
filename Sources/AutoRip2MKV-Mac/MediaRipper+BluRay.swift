import Foundation

// MARK: - Blu-ray Ripping Implementation

extension MediaRipper {

    func performBluRayRipping(blurayPath: String, configuration: RippingConfiguration) throws {
        // Step 1: Parse Blu-ray structure
        delegate?.ripperDidUpdateStatus("Analyzing Blu-ray structure...")
        blurayParser = BluRayStructureParser(blurayPath: blurayPath)
        let playlists = try blurayParser!.parseBluRayStructure()

        guard !playlists.isEmpty else {
            throw MediaRipperError.noTitlesFound
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

        // Step 3: Extract cover art if available
        delegate?.ripperDidUpdateStatus("Extracting cover art...")
        extractCoverArt(from: blurayPath, to: organizedOutputDirectory)

        // Step 4: Initialize Blu-ray decryptor
        delegate?.ripperDidUpdateStatus("Initializing Blu-ray AACS decryption...")
        blurayDecryptor = BluRayDecryptor(devicePath: blurayPath)
        try blurayDecryptor!.initializeDecryption()

        // Step 5: Determine which playlists to rip
        let playlistsToRip = filterPlaylistsToRip(playlists: playlists, selectedTitles: configuration.selectedTitles)
        delegate?.ripperDidUpdateProgress(0.0, currentItem: nil, totalItems: playlistsToRip.count)

        // Step 6: Rip each playlist to organized directory
        for (index, playlist) in playlistsToRip.enumerated() {
            if shouldCancel {
                throw MediaRipperError.cancelled
            }

            delegate?.ripperDidUpdateStatus(
                "Ripping Blu-ray playlist \(playlist.number) (\(playlist.formattedDuration))..."
            )
            try ripBluRayPlaylist(
                playlist, configuration: configuration, outputDirectory: organizedOutputDirectory,
                playlistIndex: index, totalPlaylists: playlistsToRip.count
            )
        }
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
            // Return playlists that are longer than 1 minute (to filter out menus and very short clips)
            return playlists.filter { $0.duration >= 60.0 }
        } else {
            // Return only selected playlists
            return playlists.filter { selectedTitles.contains($0.number) }
        }
    }

    /// Determine appropriate playlist name based on content and position
    private func determinePlaylistName(playlist: BluRayPlaylist, playlistIndex: Int, totalPlaylists: Int) -> String {
        // Determine if this is likely the main movie or bonus content
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
