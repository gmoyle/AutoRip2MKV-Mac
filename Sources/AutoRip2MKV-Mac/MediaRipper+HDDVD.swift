import Foundation

// MARK: - HD DVD Ripping Implementation

extension MediaRipper {

    /// Performs HD DVD ripping workflow with error recovery and notifications
    func performHDDVDRippingWorkflow(hddvdPath: String, configuration: RippingConfiguration) throws {
        Logger.shared.log("Starting HD DVD ripping for path: \(hddvdPath)", level: .info, category: .general)
        
        let maxRetries = 3
        var parser: HDDVDStructureParser? = nil
        var structure: HDDVDStructure? = nil
        var lastError: Error? = nil

        // Step 0: Analyze disc for quality optimization
        delegate?.mediaRipperDidUpdateStatus("Analyzing HD DVD quality...")
        let qualityAssessment: QualityAssessment
        do {
            qualityAssessment = try analyzeMedia(mediaPath: hddvdPath, mediaType: .hddvd)
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

        // Step 1: Parse HD DVD structure with retry
        delegate?.mediaRipperDidUpdateStatus("Parsing HD DVD structure...")
        for attempt in 1...maxRetries {
            do {
                parser = HDDVDStructureParser()
                structure = try parser?.parseStructure(at: hddvdPath)
                break
            } catch {
                lastError = error
                Logger.shared.logError(error, context: "HD DVD structure parse failed (attempt \(attempt))")
                delegate?.mediaRipperDidUpdateStatus("Structure parse failed (attempt \(attempt)). Retrying...")
                if attempt == maxRetries {
                    delegate?.mediaRipperDidFail(with: error)
                    throw error
                }
            }
        }

        guard let structureUnwrapped = structure, !structureUnwrapped.titles.isEmpty else {
            let error = MediaRipperError.noTitlesFound
            Logger.shared.logError(error, context: "No titles found in HD DVD")
            delegate?.mediaRipperDidFail(with: error)
            throw error
        }

        // Step 2: Extract movie name and create organized directory
        delegate?.mediaRipperDidUpdateStatus("Analyzing disc information...")
        let movieName = extractMovieName(from: hddvdPath, mediaType: .hddvd)
        let organizedOutputDirectory = createOrganizedOutputDirectory(
            baseDirectory: configuration.outputDirectory,
            mediaType: .hddvd,
            movieName: movieName
        )

        // Create disc info file
        createDiscInfo(in: organizedOutputDirectory, mediaPath: hddvdPath,
                      mediaType: .hddvd, movieName: movieName)
        
        // Log quality report
        Logger.shared.log(MediaRipper.generateQualityReport(qualityAssessment), level: .info, category: .general)
        Logger.shared.log("HD DVD Volume: \(structureUnwrapped.volumeLabel), Titles: \(structureUnwrapped.titles.count)", level: .info, category: .general)

        // Update configuration with recommended settings
        let optimizedConfig = RippingConfiguration(
            outputDirectory: configuration.outputDirectory,
            selectedTitles: configuration.selectedTitles,
            videoCodec: qualityAssessment.recommendedCodec,
            audioCodec: configuration.audioCodec,
            quality: .high,
            includeSubtitles: configuration.includeSubtitles,
            includeChapters: configuration.includeChapters,
            mediaType: configuration.mediaType
        )

        // Step 3: Determine which titles to rip
        let titlesToRip = filterHDDVDTitlesToRip(titles: structureUnwrapped.titles, selectedTitles: optimizedConfig.selectedTitles)
        delegate?.mediaRipperDidUpdateProgress(0.0, currentItem: nil, totalItems: titlesToRip.count)

        // Step 4: Rip each title with error recovery
        for (index, title) in titlesToRip.enumerated() {
            if shouldCancel {
                let error = MediaRipperError.cancelled
                Logger.shared.logError(error, context: "Ripping cancelled by user")
                delegate?.mediaRipperDidFail(with: error)
                throw error
            }

            delegate?.mediaRipperDidUpdateStatus("Ripping HD DVD title \(title.index): \(title.name) (\(formatDuration(title.durationSeconds)))...")
            var titleSuccess = false
            
            for attempt in 1...maxRetries {
                do {
                    try ripHDDVDTitle(title, configuration: optimizedConfig, outputDirectory: organizedOutputDirectory,
                                     titleIndex: index, totalTitles: titlesToRip.count, hddvdPath: hddvdPath)
                    titleSuccess = true
                    break
                } catch {
                    lastError = error
                    Logger.shared.logError(error, context: "Failed to rip HD DVD title \(title.index) (attempt \(attempt))")
                    delegate?.mediaRipperDidUpdateStatus("Ripping failed for title \(title.index) (attempt \(attempt)). Retrying...")
                    if attempt == maxRetries {
                        delegate?.mediaRipperDidUpdateStatus("Skipping failed title \(title.index).")
                    }
                }
            }
            
            if !titleSuccess {
                Logger.shared.log("Skipped HD DVD title \(title.index) after repeated failures.", level: .warning, category: .general)
            }
            
            // Update overall progress
            let overallProgress = Double(index + 1) / Double(titlesToRip.count)
            delegate?.mediaRipperDidUpdateProgress(overallProgress, currentItem: nil, totalItems: titlesToRip.count)
        }

        delegate?.mediaRipperDidUpdateStatus("HD DVD ripping completed.")
        Logger.shared.log("HD DVD ripping completed for \(movieName)", level: .info, category: .general)
    }

    private func ripHDDVDTitle(
        _ title: HDDVDTitle,
        configuration: RippingConfiguration,
        outputDirectory: String,
        titleIndex: Int,
        totalTitles: Int,
        hddvdPath: String
    ) throws {
        // Create intelligent output filename
        let titleName = determineHDDVDTitleName(title: title, titleIndex: titleIndex, totalTitles: totalTitles)
        let duration = formatDuration(title.durationSeconds).replacingOccurrences(of: ":", with: "-")
        let outputFileName = "\(titleName)_\(duration).mkv"
        let outputPath = outputDirectory.appending("/\(outputFileName)")

        // For HD DVD, we extract streams from EVO files in HVDVD_TS directory
        let tempVideoFile = try extractHDDVDTitle(title, hddvdPath: hddvdPath)

        // Convert to MKV using the HD DVD media item
        try convertHDDVDToMKV(
            inputFile: tempVideoFile,
            outputFile: outputPath,
            title: title,
            configuration: configuration,
            itemIndex: titleIndex,
            totalItems: totalTitles
        )

        // Cleanup temp file
        try? FileManager.default.removeItem(atPath: tempVideoFile)
    }

    private func extractHDDVDTitle(_ title: HDDVDTitle, hddvdPath: String) throws -> String {
        let tempDirectory = NSTemporaryDirectory()
        let tempFileName = "temp_hddvd_title_\(title.index).evo"
        let tempFilePath = tempDirectory.appending(tempFileName)

        // Look for EVO files in HVDVD_TS directory
        let hvdvdTSPath = (hddvdPath as NSString).appendingPathComponent("HVDVD_TS")
        let advObjPath = (hddvdPath as NSString).appendingPathComponent("ADV_OBJ")
        
        var sourceFiles: [String] = []
        let fileManager = FileManager.default
        
        // Check for EVO files (main video streams)
        for searchPath in [hvdvdTSPath, hddvdPath] {
            if fileManager.fileExists(atPath: searchPath) {
                if let contents = try? fileManager.contentsOfDirectory(atPath: searchPath) {
                    let evoFiles = contents.filter { $0.lowercased().hasSuffix(".evo") }
                    sourceFiles.append(contentsOf: evoFiles.map { (searchPath as NSString).appendingPathComponent($0) })
                }
            }
        }

        // If no EVO files found, try to find video files directly
        if sourceFiles.isEmpty {
            // Look for any video files
            let videoExtensions = [".evo", ".vob", ".m2ts", ".mpg"]
            if let enumerator = fileManager.enumerator(atPath: hddvdPath) {
                for case let file as String in enumerator {
                    if videoExtensions.contains(where: { file.lowercased().hasSuffix($0) }) {
                        sourceFiles.append((hddvdPath as NSString).appendingPathComponent(file))
                    }
                }
            }
        }

        guard !sourceFiles.isEmpty else {
            throw MediaRipperError.fileNotFound
        }

        // Combine source files into temp file (for multi-part titles)
        guard let outputHandle = createFileAndGetHandle(at: tempFilePath) else {
            throw MediaRipperError.fileCreationFailed
        }
        defer { outputHandle.closeFile() }

        var totalBytesWritten: Int64 = 0
        
        for sourceFile in sourceFiles.sorted() {
            if shouldCancel {
                throw MediaRipperError.cancelled
            }
            
            if let data = fileManager.contents(atPath: sourceFile) {
                outputHandle.write(data)
                totalBytesWritten += Int64(data.count)
                
                // Update progress
                delegate?.mediaRipperDidUpdateStatus("Extracting: \((sourceFile as NSString).lastPathComponent)")
            }
        }

        return tempFilePath
    }

    /// Convert HD DVD content to MKV
    private func convertHDDVDToMKV(
        inputFile: String,
        outputFile: String,
        title: HDDVDTitle,
        configuration: RippingConfiguration,
        itemIndex: Int,
        totalItems: Int
    ) throws {
        // Build FFmpeg command
        let ffmpegPath = try getFFmpegPathForHDDVD()

        var arguments = [
            "-i", inputFile,
            "-c:v", videoCodecArgumentForHDDVD(for: configuration.videoCodec),
            "-crf", "\(configuration.quality.crf)",
            "-c:a", audioCodecArgumentForHDDVD(for: configuration.audioCodec)
        ]

        // Add subtitle handling if requested
        if configuration.includeSubtitles {
            arguments.append(contentsOf: ["-c:s", "copy"])
        }

        // Add chapter handling if requested
        if configuration.includeChapters {
            arguments.append(contentsOf: ["-map_chapters", "0"])
        }

        // Map all streams
        arguments.append(contentsOf: ["-map", "0"])
        
        // Output file
        arguments.append("-y") // Overwrite if exists
        arguments.append(outputFile)

        // Run FFmpeg conversion
        try runHDDVDConversion(
            ffmpegPath: ffmpegPath,
            arguments: arguments,
            title: title,
            itemIndex: itemIndex,
            totalItems: totalItems
        )
    }

    private func getFFmpegPathForHDDVD() throws -> String {
        // Check bundled first
        let bundlePath = Bundle.main.bundlePath
        let bundledFFmpeg = bundlePath.appending("/Contents/Resources/ffmpeg")
        if FileManager.default.fileExists(atPath: bundledFFmpeg) {
            return bundledFFmpeg
        }

        if let bundledPath = Bundle.main.path(forResource: "ffmpeg", ofType: nil) {
            return bundledPath
        }

        // Check Application Support
        let fileManager = FileManager.default
        guard let appSupportURL = fileManager.urls(for: .applicationSupportDirectory,
                                                   in: .userDomainMask).first else {
            throw MediaRipperError.ffmpegNotFound
        }
        let appPath = appSupportURL.appendingPathComponent("AutoRip2MKV-Mac")
        let installedFFmpeg = appPath.appendingPathComponent("ffmpeg").path
        if fileManager.fileExists(atPath: installedFFmpeg) {
            return installedFFmpeg
        }

        // Check system PATH
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["ffmpeg"]
        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !path.isEmpty {
                    return path
                }
            }
        } catch {
            throw MediaRipperError.ffmpegNotFound
        }

        throw MediaRipperError.ffmpegNotFound
    }

    private func videoCodecArgumentForHDDVD(for codec: RippingConfiguration.VideoCodec) -> String {
        switch codec {
        case .h264: return "libx264"
        case .h265: return "libx265"
        case .av1: return "libaom-av1"
        case .vp9: return "libvpx-vp9"
        }
    }

    private func audioCodecArgumentForHDDVD(for codec: RippingConfiguration.AudioCodec) -> String {
        switch codec {
        case .aac: return "aac"
        case .ac3: return "ac3"
        case .dts: return "dca"
        case .flac: return "flac"
        }
    }

    private func runHDDVDConversion(
        ffmpegPath: String,
        arguments: [String],
        title: HDDVDTitle,
        itemIndex: Int,
        totalItems: Int
    ) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffmpegPath)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardError = pipe

        try process.run()

        // Monitor progress
        let progressQueue = DispatchQueue(label: "ffmpeg.hddvd.progress")
        progressQueue.async {
            self.monitorHDDVDProgress(pipe: pipe, title: title, itemIndex: itemIndex, totalItems: totalItems)
        }

        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw MediaRipperError.conversionFailed
        }
    }

    private func monitorHDDVDProgress(pipe: Pipe, title: HDDVDTitle, itemIndex: Int, totalItems: Int) {
        let fileHandle = pipe.fileHandleForReading
        var buffer = Data()
        let delimiter = Data("\r".utf8)

        while !shouldCancel {
            let chunk = fileHandle.availableData
            if chunk.isEmpty { break }

            buffer.append(chunk)

            while let delimiterRange = buffer.range(of: delimiter) {
                let lineData = buffer.subdata(in: 0..<delimiterRange.lowerBound)
                buffer.removeSubrange(0..<delimiterRange.upperBound)

                if let line = String(data: lineData, encoding: .utf8) {
                    parseHDDVDProgress(line: line, title: title, itemIndex: itemIndex, totalItems: totalItems)
                }
            }

            usleep(10000) // 10ms
        }
    }

    private func parseHDDVDProgress(line: String, title: HDDVDTitle, itemIndex: Int, totalItems: Int) {
        if line.contains("time=") {
            let components = line.components(separatedBy: " ")
            for component in components {
                if component.hasPrefix("time=") {
                    let timeString = String(component.dropFirst(5))
                    if let currentTime = parseHDDVDTimeString(timeString) {
                        let totalDuration = Double(title.durationSeconds)
                        let conversionProgress = min(currentTime / totalDuration, 1.0)
                        let overallProgress = 0.5 + (conversionProgress * 0.5) // 50-100% for conversion

                        DispatchQueue.main.async {
                            self.delegate?.mediaRipperDidUpdateProgress(overallProgress, currentItem: nil, totalItems: totalItems)
                        }
                    }
                    break
                }
            }
        }
    }

    private func parseHDDVDTimeString(_ timeString: String) -> Double? {
        let components = timeString.components(separatedBy: ":")
        guard components.count == 3 else { return nil }

        guard let hours = Double(components[0]),
              let minutes = Double(components[1]),
              let seconds = Double(components[2]) else {
            return nil
        }

        return hours * 3600 + minutes * 60 + seconds
    }

    private func filterHDDVDTitlesToRip(titles: [HDDVDTitle], selectedTitles: [Int]) -> [HDDVDTitle] {
        if selectedTitles.isEmpty {
            // Return all titles that are longer than 1 minute
            return titles.filter { $0.durationSeconds >= 60 }
        } else {
            return titles.filter { selectedTitles.contains($0.index) }
        }
    }

    private func determineHDDVDTitleName(title: HDDVDTitle, titleIndex: Int, totalTitles: Int) -> String {
        // Determine if this is likely the main movie or bonus content
        let isMainTitle = (titleIndex == 0 && title.durationSeconds > 3600) ||
                         (title.durationSeconds >= 5400) ||
                         (totalTitles == 1)

        if isMainTitle {
            return "Main_Movie"
        } else if title.durationSeconds >= 3600 { // 60+ minutes
            return "Feature_\(String(format: "%02d", title.index))"
        } else if title.durationSeconds >= 1800 { // 30+ minutes
            return "Extended_Content_\(String(format: "%02d", title.index))"
        } else if title.durationSeconds >= 300 { // 5+ minutes
            return "Bonus_Content_\(String(format: "%02d", title.index))"
        } else {
            return "Short_\(String(format: "%02d", title.index))"
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, secs)
    }
}
