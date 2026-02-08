import Foundation

// MARK: - DVD Ripping Implementation

extension MediaRipper {

    func performDVDRipping(dvdPath: String, configuration: RippingConfiguration) throws {

        let maxRetries = 3
        var titles: [DVDTitle] = []
        var lastError: Error? = nil

        // Step 0: Analyze disc for quality optimization
        delegate?.ripperDidUpdateStatus("Analyzing disc quality...")
        let qualityAssessment: QualityAssessment
        do {
            qualityAssessment = try analyzeMedia(mediaPath: dvdPath, mediaType: .dvd)
        } catch {
            Logger.shared.logError(error, context: "Quality analysis failed; using default settings.")
            // Fallback: use default configuration
            qualityAssessment = QualityAssessment(
                resolution: .fullHD1080p,
                estimatedBitrate: 6000,
                contentType: .liveAction,
                complexityScore: 6.0,
                hdrPresent: false,
                audioTracks: [],
                recommendedCodec: configuration.videoCodec,
                recommendedCRF: configuration.quality.crf,
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
        }

        // Step 1: Parse DVD structure with retry
        delegate?.ripperDidUpdateStatus("Analyzing DVD structure...")
        for attempt in 1...maxRetries {
            do {
                dvdParser = DVDStructureParser(dvdPath: dvdPath)
                titles = try dvdParser!.parseDVDStructure()
                break
            } catch {
                lastError = error
                Logger.shared.logError(error, context: "DVD structure parse failed (attempt \(attempt))")
                delegate?.ripperDidUpdateStatus("Structure parse failed (attempt \(attempt)). Retrying...")
                if attempt == maxRetries {
                    delegate?.ripperDidFail(with: error)
                    throw error
                }
            }
        }

        guard !titles.isEmpty else {
            let error = MediaRipperError.noTitlesFound
            Logger.shared.logError(error, context: "No titles found in DVD")
            delegate?.ripperDidFail(with: error)
            throw error
        }

        // Step 2: Extract movie name and create organized directory
        delegate?.ripperDidUpdateStatus("Analyzing disc information...")
        let movieName = extractMovieName(from: dvdPath, mediaType: currentMediaType)
        let organizedOutputDirectory = createOrganizedOutputDirectory(
            baseDirectory: configuration.outputDirectory,
            mediaType: currentMediaType,
            movieName: movieName
        )

        // Create disc info file
        createDiscInfo(in: organizedOutputDirectory, mediaPath: dvdPath,
                      mediaType: currentMediaType, movieName: movieName)
        // Log quality report
        Logger.shared.log(MediaRipper.generateQualityReport(qualityAssessment), level: .info, category: .general)

        // Update configuration with recommended settings
        let optimizedConfig = RippingConfiguration(
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

        // Use optimizedConfig for subsequent ripping steps
        // Step 3: Initialize DVD decryptor with retry
        delegate?.ripperDidUpdateStatus("Initializing DVD CSS decryption...")
        var devicePath: String? = nil
        for attempt in 1...maxRetries {
            devicePath = findDVDDevice(dvdPath: dvdPath)
            if let path = devicePath {
                do {
                    dvdDecryptor = DVDDecryptor(devicePath: path)
                    try dvdDecryptor!.initializeDevice()
                    break
                } catch {
                    lastError = error
                    Logger.shared.logError(error, context: "DVD decryptor init failed (attempt \(attempt))")
                    delegate?.ripperDidUpdateStatus("Decryptor init failed (attempt \(attempt)). Retrying...")
                    if attempt == maxRetries {
                        delegate?.ripperDidFail(with: error)
                        throw error
                    }
                }
            } else {
                lastError = MediaRipperError.deviceNotFound
                Logger.shared.logError(lastError!, context: "DVD device not found (attempt \(attempt))")
                delegate?.ripperDidUpdateStatus("Device not found (attempt \(attempt)). Retrying...")
                if attempt == maxRetries {
                    delegate?.ripperDidFail(with: lastError!)
                    throw lastError!
                }
            }
        }

        // Step 4: Determine which titles to rip
        let titlesToRip = filterTitlesToRip(titles: titles, selectedTitles: optimizedConfig.selectedTitles)
        delegate?.ripperDidUpdateProgress(0.0, currentItem: nil, totalItems: titlesToRip.count)

        // Step 5: Rip each title to organized directory with error recovery
        for (index, title) in titlesToRip.enumerated() {
            if shouldCancel {
                let error = MediaRipperError.cancelled
                Logger.shared.logError(error, context: "Ripping cancelled by user")
                delegate?.ripperDidFail(with: error)
                throw error
            }

            delegate?.ripperDidUpdateStatus("Ripping DVD title \(title.number) (\(title.formattedDuration))...")
            var titleSuccess = false
            for attempt in 1...maxRetries {
                do {
                    try ripDVDTitle(title, configuration: optimizedConfig, outputDirectory: organizedOutputDirectory,
                                   titleIndex: index, totalTitles: titlesToRip.count)
                    titleSuccess = true
                    break
                } catch {
                    lastError = error
                    Logger.shared.logError(error, context: "Failed to rip title \(title.number) (attempt \(attempt))")
                    delegate?.ripperDidUpdateStatus("Ripping failed for title \(title.number) (attempt \(attempt)). Retrying...")
                    if attempt == maxRetries {
                        delegate?.ripperDidUpdateStatus("Skipping failed title \(title.number).")
                        // Optionally, continue with next title instead of failing all
                    }
                }
            }
            if !titleSuccess {
                // Log and notify about skipped title
                Logger.shared.log("Skipped title \(title.number) after repeated failures.", level: .warning, category: .general)
            }
        }
        // All titles processed
        delegate?.ripperDidUpdateStatus("DVD ripping completed.")
        delegate?.ripperDidUpdateProgress(0.0, currentItem: nil, totalItems: titlesToRip.count)

        // Step 5: Rip each title to organized directory with error recovery
        for (index, title) in titlesToRip.enumerated() {
            if shouldCancel {
                let error = MediaRipperError.cancelled
                Logger.shared.logError(error, context: "Ripping cancelled by user")
                delegate?.ripperDidFail(with: error)
                throw error
            }

            delegate?.ripperDidUpdateStatus("Ripping DVD title \(title.number) (\(title.formattedDuration))...")
            var titleSuccess = false
            for attempt in 1...maxRetries {
                do {
                    try ripDVDTitle(title, configuration: configuration, outputDirectory: organizedOutputDirectory,
                                   titleIndex: index, totalTitles: titlesToRip.count)
                    titleSuccess = true
                    break
                } catch {
                    lastError = error
                    Logger.shared.logError(error, context: "Failed to rip title \(title.number) (attempt \(attempt))")
                    delegate?.ripperDidUpdateStatus("Ripping failed for title \(title.number) (attempt \(attempt)). Retrying...")
                    if attempt == maxRetries {
                        delegate?.ripperDidUpdateStatus("Skipping failed title \(title.number).")
                        // Optionally, continue with next title instead of failing all
                    }
                }
            }
            if !titleSuccess {
                // Log and notify about skipped title
                Logger.shared.log("Skipped title \(title.number) after repeated failures.", level: .warning, category: .general)
            }
        }
        // All titles processed
        delegate?.ripperDidUpdateStatus("DVD ripping completed.")
    }

    private func ripDVDTitle(_ title: DVDTitle, configuration: RippingConfiguration, outputDirectory: String, titleIndex: Int, totalTitles: Int) throws {
        // Get title key for decryption
        let titleKey = try dvdDecryptor!.getTitleKey(titleNumber: title.number, startSector: title.startSector)

        // Create intelligent output filename
        let titleName = determineTitleName(title: title, titleIndex: titleIndex, totalTitles: totalTitles)
        let outputFileName = "\(titleName)_\(title.formattedDuration.replacingOccurrences(of: ":", with: "-")).mkv"
        let outputPath = outputDirectory.appending("/\(outputFileName)")

        // Extract and decrypt video data
        let tempVideoFile = try extractAndDecryptDVDTitle(title, titleKey: titleKey)

        // Convert to MKV
        try convertToMKV(
            inputFile: tempVideoFile,
            outputFile: outputPath,
            mediaItem: .dvdTitle(title),
            configuration: configuration,
            itemIndex: titleIndex,
            totalItems: totalTitles
        )

        // Cleanup temp file
        try? FileManager.default.removeItem(atPath: tempVideoFile)
    }

    private func extractAndDecryptDVDTitle(_ title: DVDTitle, titleKey: DVDDecryptor.CSSKey) throws -> String {
        let tempDirectory = NSTemporaryDirectory()
        let tempFileName = "temp_dvd_title_\(title.number).vob"
        let tempFilePath = tempDirectory.appending(tempFileName)

        guard let outputHandle = FileHandle(forWritingAtPath: tempFilePath) ??
              createFileAndGetHandle(at: tempFilePath) else {
            throw MediaRipperError.fileCreationFailed
        }

        defer { outputHandle.closeFile() }

        var totalBytesRead: Int64 = 0
        let totalSize = Int64(title.sectors) * 2048 // DVD sector size

        // Read and decrypt sectors
        for sectorOffset in stride(from: 0, to: title.sectors, by: 1024) { // Read in chunks
            if shouldCancel {
                throw MediaRipperError.cancelled
            }

            let sectorsToRead = min(1024, title.sectors - sectorOffset)
            let startSector = title.startSector + sectorOffset

            // Read encrypted data
            let encryptedData = try dvdDecryptor!.readSectors(startSector: startSector, sectorCount: Int(sectorsToRead))

            // Decrypt data
            let decryptedData = try dvdDecryptor!.decryptSectors(
                data: encryptedData, titleKey: titleKey, startSector: startSector
            )

            // Write to temp file
            outputHandle.write(decryptedData)

            totalBytesRead += Int64(decryptedData.count)

            // Update progress
            let progress = Double(totalBytesRead) / Double(totalSize)
            delegate?.ripperDidUpdateProgress(
                progress * 0.5, currentItem: .dvdTitle(title), totalItems: 1
            ) // 50% for extraction
        }

        return tempFilePath
    }

    internal func createFileAndGetHandle(at path: String) -> FileHandle? {
        FileManager.default.createFile(atPath: path, contents: nil, attributes: nil)
        return FileHandle(forWritingAtPath: path)
    }

    private func findDVDDevice(dvdPath: String) -> String? {
        // Check if it's already a device path
        if dvdPath.hasPrefix("/dev/") {
            return dvdPath
        }

        // Try to find the device path for the mount point
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/df")
        process.arguments = [dvdPath]

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let lines = output.components(separatedBy: .newlines)
                for line in lines {
                    if line.contains(dvdPath) {
                        let components = line.components(separatedBy: .whitespaces)
                        if let devicePath = components.first, devicePath.hasPrefix("/dev/") {
                            return devicePath
                        }
                    }
                }
            }
        } catch {
            // Fall back to guessing based on path
        }

        // Default fallback - assume it's a disc image or try common device paths
        return "/dev/disk1" // This should be determined more intelligently
    }

    private func filterTitlesToRip(titles: [DVDTitle], selectedTitles: [Int]) -> [DVDTitle] {
        if selectedTitles.isEmpty {
            // Use intelligent filtering when no titles explicitly selected
            if SettingsManager.shared.intelligentTitleSelection {
                let analyzer = TitleAnalyzer()
                let rules = SettingsManager.shared.getTitleFilteringRules()
                let filtered = analyzer.filterDVDTitles(titles, rules: rules)
                
                Logger.shared.log(
                    "Intelligent title filtering: \(titles.count) titles → \(filtered.count) selected",
                    level: .info,
                    category: .general
                )
                
                return filtered
            } else {
                // Fallback to basic duration filter
                return titles.filter { $0.duration >= 60.0 }
            }
        } else {
            // Return only explicitly selected titles
            return titles.filter { selectedTitles.contains($0.number) }
        }
    }

    /// Determine appropriate title name based on content and position
    private func determineTitleName(title: DVDTitle, titleIndex: Int, totalTitles: Int) -> String {
        // Use intelligent classification if enabled
        if SettingsManager.shared.intelligentTitleSelection {
            let analyzer = TitleAnalyzer()
            let rules = SettingsManager.shared.getTitleFilteringRules()
            let scores = analyzer.analyzeDVDTitles([title], rules: rules)
            
            if let score = scores.first {
                switch score.classification {
                case .mainFeature:
                    return "Main_Movie"
                case .extendedEdition:
                    return "Extended_Edition"
                case .bonusFeature:
                    return "Bonus_Feature_\(String(format: "%02d", title.number))"
                case .trailer:
                    return "Trailer_\(String(format: "%02d", title.number))"
                case .menu:
                    return "Menu_\(String(format: "%02d", title.number))"
                case .duplicate:
                    return "Duplicate_\(String(format: "%02d", title.number))"
                case .unknown:
                    return "Title_\(String(format: "%02d", title.number))"
                }
            }
        }
        
        // Fallback to legacy heuristic classification
        let isMainTitle = (titleIndex == 0 && title.duration > 3600) || // First title over 1 hour
                         (title.duration >= 5400) || // Any title over 90 minutes
                         (totalTitles == 1) // Only one title

        if isMainTitle {
            return "Main_Movie"
        } else if title.duration >= 1800 { // 30+ minutes
            return "Feature_\(String(format: "%02d", title.number))"
        } else if title.duration >= 300 { // 5+ minutes
            return "Bonus_Content_\(String(format: "%02d", title.number))"
        } else {
            return "Short_\(String(format: "%02d", title.number))"
        }
    }
}
