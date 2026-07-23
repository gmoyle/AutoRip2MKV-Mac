import Foundation

// MARK: - DVD Ripping Implementation

extension MediaRipper {

    func performDVDRipping(dvdPath: String, configuration: RippingConfiguration) throws {
        // Step 1: Parse DVD structure
        delegate?.mediaRipperDidUpdateStatus("Analyzing DVD structure...")
        dvdParser = DVDStructureParser(dvdPath: dvdPath)
        let titles = try dvdParser!.parseDVDStructure()

        guard !titles.isEmpty else {
            let error = MediaRipperError.noTitlesFound
            Logger.shared.logError(error, context: "No titles found in DVD")
            delegate?.mediaRipperDidFail(with: error)
            throw error
        }

        // Step 2: Determine the output directory. With a resolved title, use
        // Plex-style "<output>/<Movie (Year)>/"; otherwise the media-type layout.
        delegate?.mediaRipperDidUpdateStatus("Analyzing disc information...")
        let movieName = extractMovieName(from: dvdPath, mediaType: currentMediaType)
        let organizedOutputDirectory: String
        if let plexBase = plexBaseName(from: configuration) {
            organizedOutputDirectory = configuration.outputDirectory.appending("/\(plexBase)")
            try? FileManager.default.createDirectory(
                atPath: organizedOutputDirectory, withIntermediateDirectories: true)
        } else {
            organizedOutputDirectory = createOrganizedOutputDirectory(
                baseDirectory: configuration.outputDirectory,
                mediaType: currentMediaType,
                movieName: movieName
            )
        }

        // Create disc info file
        createDiscInfo(in: organizedOutputDirectory, mediaPath: dvdPath,
                      mediaType: currentMediaType, movieName: movieName)

        // Step 3: Initialize DVD decryptor using raw device for hardware CSS auth
        delegate?.mediaRipperDidUpdateStatus("Initializing DVD CSS decryption...")
        let rawDevice = findRawDVDDevice(dvdPath: dvdPath)
        guard let rawDevice = rawDevice else {
            throw MediaRipperError.deviceNotFound
        }
        delegate?.mediaRipperDidUpdateStatus("Using device: \(rawDevice)")
        dvdDecryptor = DVDDecryptor(devicePath: rawDevice)
        try dvdDecryptor!.initializeDevice()

        // Step 4: Determine which titles to rip
        let titlesToRip = filterTitlesToRip(titles: titles, selectedTitles: configuration.selectedTitles)
        delegate?.mediaRipperDidUpdateStatus("Titles to rip: \(titlesToRip.map({ $0.number }))")
        delegate?.mediaRipperDidUpdateProgress(0.0, currentItem: nil, totalItems: titlesToRip.count)

        // Step 5: Feed each title's decrypted sectors into its ffmpeg stdin pipe.
        // Processes are collected in backgroundEncodingProcesses so the ConversionQueue
        // can wait on them (serialised) after the disc is ejected.
        backgroundEncodingProcesses.removeAll()

        isFeedingDisc = true
        defer { isFeedingDisc = false }

        for (index, title) in titlesToRip.enumerated() {
            if shouldCancel {
                let error = MediaRipperError.cancelled
                Logger.shared.logError(error, context: "Ripping cancelled by user")
                delegate?.mediaRipperDidFail(with: error)
                throw error
            }

            let titleName = determineTitleName(title: title, titleIndex: index, totalTitles: titlesToRip.count)
            let outputFileName: String
            if let plexBase = plexBaseName(from: configuration) {
                // Main feature is "<Movie (Year)>.mkv" so Plex matches it directly;
                // any extra titles get a distinguishing suffix
                outputFileName = index == 0 ? "\(plexBase).mkv" : "\(plexBase) - \(titleName).mkv"
            } else {
                outputFileName = "\(titleName)_\(title.formattedDuration.replacingOccurrences(of: ":", with: "-")).mkv"
            }
            let outputPath = organizedOutputDirectory.appending("/\(outputFileName)")

            // Remove any stale/incomplete output from a prior interrupted run
            if FileManager.default.fileExists(atPath: outputPath) {
                try? FileManager.default.removeItem(atPath: outputPath)
            }
            let stagingPath = encodingStagingPath(for: outputPath)
            if FileManager.default.fileExists(atPath: stagingPath) {
                try? FileManager.default.removeItem(atPath: stagingPath)
            }

            delegate?.mediaRipperDidUpdateStatus("Ripping title \(title.number) (\(title.formattedDuration)) → \(outputFileName)...")
            let titleKey = try dvdDecryptor!.getTitleKey(titleNumber: title.number, startSector: title.startSector)
            let process = try feedDVDTitleToFFmpeg(title, titleKey: titleKey, outputPath: outputPath,
                                                   configuration: configuration, titleIndex: index,
                                                   totalTitles: titlesToRip.count)
            backgroundEncodingProcesses.append((process: process, outputPath: outputPath,
                                                stagingPath: stagingPath, titleNumber: title.number))
        }

        // Release the raw device before requesting eject — libdvdcss's open file
        // descriptor would otherwise make the physical eject fail as busy.
        dvdDecryptor?.closeDevice()
        dvdDecryptor = nil

        // All sectors fed — disc can be ejected.
        // mediaRipperDidComplete signals the queue/UI to eject and advance the job to .encoding.
        // The queue's performConversion then waits on backgroundEncodingProcesses serially.
        delegate?.mediaRipperDidUpdateStatus("All titles read from disc. Encoding continues in background...")
        DispatchQueue.main.async {
            self.delegate?.mediaRipperDidComplete()
            self.isRipping = false
        }
    }

    /// Starts an ffmpeg process and feeds all decrypted sectors into its stdin pipe.
    /// Returns the running Process as soon as the last sector is written — the caller
    /// is responsible for waiting on it (after the disc is ejected).
    private func feedDVDTitleToFFmpeg(_ title: DVDTitle, titleKey: DVDDecryptor.CSSKey,
                                      outputPath: String, configuration: RippingConfiguration,
                                      titleIndex: Int, totalTitles: Int) throws -> Process {
        let ffmpegPath = try getFFmpegPath()

        // Large probe window: audio/subtitle substreams in a piped MPEG-PS appear
        // sporadically, and ffmpeg's default quick scan misses them entirely.
        var args = ["-probesize", "200M", "-analyzeduration", "120M",
                    "-i", "-",
                    "-map", "0:v:0", "-map", "0:a?"]
        if configuration.includeSubtitles { args.append(contentsOf: ["-map", "0:s?"]) }
        args.append(contentsOf: ["-c:v", videoCodecArgument(for: configuration.videoCodec)])
        args.append(contentsOf: codecSpecificArguments(for: configuration.videoCodec, quality: configuration.quality))
        if configuration.autoDeinterlace {
            // deint=interlaced only touches frames flagged interlaced (NTSC DVDs);
            // progressive content passes through untouched
            args.append(contentsOf: ["-vf", "bwdif=mode=send_frame:parity=auto:deint=interlaced"])
        }
        args.append(contentsOf: ["-c:a", audioCodecArgument(for: configuration.audioCodec)])
        if configuration.includeSubtitles { args.append(contentsOf: ["-c:s", "copy"]) }
        if configuration.includeChapters  { args.append(contentsOf: ["-map_chapters", "0"]) }

        // Label tracks with languages from the VTS IFO (stream order)
        for (index, lang) in title.audioLanguages.enumerated() where !lang.isEmpty {
            args.append(contentsOf: ["-metadata:s:a:\(index)", "language=\(iso639_2(from: lang))"])
        }
        if configuration.includeSubtitles {
            for (index, lang) in title.subtitleLanguages.enumerated() where !lang.isEmpty {
                args.append(contentsOf: ["-metadata:s:s:\(index)", "language=\(iso639_2(from: lang))"])
            }
        }
        // Encode into local staging; the queue moves the file into the (possibly
        // cloud-synced) output directory only after ffmpeg exits successfully.
        args.append(contentsOf: ["-f", "matroska", "-y", encodingStagingPath(for: outputPath)])

        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffmpegPath)
        process.arguments = args

        let stdinPipe  = Pipe()
        let stderrPipe = Pipe()
        process.standardInput  = stdinPipe
        process.standardError  = stderrPipe
        process.standardOutput = Pipe()

        try process.run()
        activeFFmpegProcess = process

        let progressQueue = DispatchQueue(label: "ffmpeg.progress.\(title.number)")
        progressQueue.async {
            self.monitorFFmpegProgress(pipe: stderrPipe, mediaItem: .dvdTitle(title),
                                       itemIndex: titleIndex, totalItems: totalTitles)
        }

        let totalSectors: UInt32
        if !title.vobFiles.isEmpty {
            let totalBytes = title.vobFiles.reduce(Int64(0)) { acc, path in
                acc + ((try? FileManager.default.attributesOfItem(atPath: path)[.size] as? Int64) ?? 0)
            }
            totalSectors = totalBytes > 0 ? UInt32(totalBytes / 2048) : max(title.sectors, 1)
        } else {
            totalSectors = max(title.sectors, 1)
        }
        delegate?.mediaRipperDidUpdateStatus("Reading \(totalSectors) sectors for title \(title.number) via libdvdcss...")

        var sectorOffset: UInt32 = 0
        let stdinHandle = stdinPipe.fileHandleForWriting

        do {
            while sectorOffset < totalSectors {
                if shouldCancel {
                    stdinHandle.closeFile()
                    process.terminate()
                    activeFFmpegProcess = nil
                    throw MediaRipperError.cancelled
                }

                let sectorsToRead = Int(min(UInt32(1024), totalSectors - sectorOffset))
                let startSector = title.startSector + sectorOffset

                let decryptedData = try dvdDecryptor!.readAndDecryptSectors(
                    startSector: startSector, sectorCount: sectorsToRead)

                if !decryptedData.isEmpty {
                    stdinHandle.write(decryptedData)
                }
                sectorOffset += UInt32(sectorsToRead)

                // Report disc-read progress every ~32MB (16 chunks of 1024 sectors)
                if sectorOffset % 16384 == 0 || sectorOffset >= totalSectors {
                    let titleFraction = Double(sectorOffset) / Double(totalSectors)
                    let overall = (Double(titleIndex) + titleFraction) / Double(max(totalTitles, 1))
                    DispatchQueue.main.async {
                        self.delegate?.mediaRipperDidUpdateProgress(
                            overall, currentItem: .dvdTitle(title), totalItems: totalTitles)
                    }
                }
            }
        } catch {
            stdinHandle.closeFile()
            process.terminate()
            activeFFmpegProcess = nil
            throw error
        }

        // Close stdin — ffmpeg will finish encoding what it has received and exit cleanly.
        stdinHandle.closeFile()
        return process
    }


    /// Convert an ISO 639-1 code from the DVD IFO to the ISO 639-2/B code
    /// Matroska and Plex expect. Unknown codes pass through unchanged.
    private func iso639_2(from code: String) -> String {
        let map: [String: String] = [
            "en": "eng", "fr": "fra", "es": "spa", "de": "deu", "it": "ita",
            "ja": "jpn", "zh": "zho", "ko": "kor", "pt": "por", "ru": "rus",
            "nl": "nld", "sv": "swe", "no": "nor", "da": "dan", "fi": "fin",
            "pl": "pol", "tr": "tur", "ar": "ara", "he": "heb", "hi": "hin",
            "th": "tha", "cs": "ces", "el": "ell", "hu": "hun", "iw": "heb"
        ]
        return map[code] ?? code
    }

    internal func createFileAndGetHandle(at path: String) -> FileHandle? {
        FileManager.default.createFile(atPath: path, contents: nil, attributes: nil)
        return FileHandle(forWritingAtPath: path)
    }

    /// Find the raw character device for the DVD (e.g. /dev/rdisk18).
    /// libdvdcss requires the raw device for hardware CSS authentication.
    private func findRawDVDDevice(dvdPath: String) -> String? {
        // Already a raw device
        if dvdPath.hasPrefix("/dev/r") { return dvdPath }
        // Block device -> convert to raw
        if dvdPath.hasPrefix("/dev/disk") {
            return dvdPath.replacingOccurrences(of: "/dev/disk", with: "/dev/rdisk")
        }

        // Mount point -> get block device via diskutil, then convert to raw
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        process.arguments = ["info", "-plist", dvdPath]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
               let deviceNode = plist["DeviceNode"] as? String {
                // deviceNode is like /dev/disk18 -> convert to /dev/rdisk18
                return deviceNode.replacingOccurrences(of: "/dev/disk", with: "/dev/rdisk")
            }
        } catch {}

        return nil
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
                // Skip header line; last non-empty line is the filesystem entry
                let dataLines = lines.filter { !$0.isEmpty && !$0.hasPrefix("Filesystem") }
                if let line = dataLines.last {
                    let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                    if let devicePath = components.first, devicePath.hasPrefix("/dev/") {
                        return devicePath
                    }
                }
            }
        } catch {
            // Fall back to guessing based on path
        }

        // Try common macOS optical drive device paths
        let candidates = ["/dev/disk2", "/dev/disk3", "/dev/disk4", "/dev/disk1"]
        for candidate in candidates {
            if FileManager.default.fileExists(atPath: candidate) {
                // Check if it looks like an optical drive by seeing if dvd path is under /Volumes
                if dvdPath.hasPrefix("/Volumes/") {
                    return candidate
                }
            }
        }
        return nil
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
