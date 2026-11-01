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
            throw error
        }

        // Step 2: Determine the output directory. With a resolved title, use
        // Plex-style "<output>/<Movie (Year)>/"; otherwise the media-type layout.
        delegate?.mediaRipperDidUpdateStatus("Analyzing disc information...")
        let movieName = extractMovieName(from: dvdPath, mediaType: currentMediaType)
        let organizedOutputDirectory = organizedDirectory(
            for: configuration, mediaType: currentMediaType, fallbackName: movieName)

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

        // Step 5: Read each title's decrypted sectors into local staging at full
        // drive speed, then queue its encode. Encoding straight from the disc
        // (ffmpeg on a stdin pipe) throttled the drive to encoder speed and kept
        // the disc — and the next job — waiting for the whole encode.
        // A retry starts over from the first title; drop anything a failed earlier
        // attempt staged.
        discardPendingEncodes()
        let ffmpegPath = try getFFmpegPath()
        try preflightStagingSpace(for: titlesToRip)

        isFeedingDisc = true
        defer { isFeedingDisc = false }

        for (index, title) in titlesToRip.enumerated() {
            if shouldCancel {
                let error = MediaRipperError.cancelled
                Logger.shared.logError(error, context: "Ripping cancelled by user")
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
            let sourcePath = encodingStagingPath(for: outputPath + ".vob")
            for path in [stagingPath, sourcePath] where FileManager.default.fileExists(atPath: path) {
                try? FileManager.default.removeItem(atPath: path)
            }

            delegate?.mediaRipperDidUpdateStatus("Ripping title \(title.number) (\(title.formattedDuration)) → \(outputFileName)...")
            _ = try dvdDecryptor!.getTitleKey(titleNumber: title.number, startSector: title.startSector)
            do {
                try readDVDTitle(title, to: sourcePath, titleIndex: index, totalTitles: titlesToRip.count)
            } catch {
                try? FileManager.default.removeItem(atPath: sourcePath)
                throw error
            }
            pendingEncodes.append(PendingEncode(
                ffmpegPath: ffmpegPath,
                arguments: dvdEncodeArguments(for: title, input: sourcePath, output: stagingPath,
                                              configuration: configuration),
                sourcePath: sourcePath, outputPath: outputPath, stagingPath: stagingPath,
                titleNumber: title.number, mediaItem: .dvdTitle(title),
                itemIndex: index, totalItems: titlesToRip.count))
        }

        // Release the raw device before requesting eject — libdvdcss's open file
        // descriptor would otherwise make the physical eject fail as busy.
        dvdDecryptor?.closeDevice()
        dvdDecryptor = nil

        // All titles are on local disk — the disc can be ejected. mediaRipperDidComplete
        // signals the queue to eject and run pendingEncodes; the next disc can rip meanwhile.
        delegate?.mediaRipperDidUpdateStatus("All titles read from disc. Encoding continues in background...")
        DispatchQueue.main.async {
            self.delegate?.mediaRipperDidComplete()
            self.isRipping = false
        }
    }

    /// Bytes on disc for `title` (from its VOB sizes when known).
    private func sectorCount(of title: DVDTitle) -> UInt32 {
        if !title.vobFiles.isEmpty {
            let totalBytes = title.vobFiles.reduce(Int64(0)) { acc, path in
                acc + ((try? FileManager.default.attributesOfItem(atPath: path)[.size] as? Int64) ?? 0)
            }
            if totalBytes > 0 { return UInt32(totalBytes / 2048) }
        }
        return max(title.sectors, 1)
    }

    /// Refuse up front if local staging can't hold the decrypted titles (plus
    /// headroom for the encodes), rather than failing partway through the disc.
    private func preflightStagingSpace(for titles: [DVDTitle]) throws {
        let stagingDir = (encodingStagingPath(for: "probe") as NSString).deletingLastPathComponent
        let needed = Int64(Double(titles.reduce(Int64(0)) { $0 + Int64(sectorCount(of: $1)) * 2048 }) * 1.25)
        if let free = MakeMKVBackend.freeSpace(atPath: stagingDir), free < needed {
            throw ConversionQueueError.insufficientDiskSpace(required: needed, available: free)
        }
    }

    /// Most unreadable sectors tolerated per title before giving up (8 MB, a few
    /// seconds of video). Past that the disc is too damaged for a usable rip.
    static let maxSkippedSectorsPerTitle = 4096

    /// Read and decrypt every sector of `title` into the file at `path`.
    /// Unreadable sectors (scratches) are re-read one at a time and, if they
    /// still fail, written as zeros — ffmpeg resyncs at the next pack header — so
    /// a small scratch costs a glitch instead of the whole disc.
    private func readDVDTitle(_ title: DVDTitle, to path: String,
                              titleIndex: Int, totalTitles: Int) throws {
        let totalSectors = sectorCount(of: title)
        delegate?.mediaRipperDidUpdateStatus("Reading \(totalSectors) sectors for title \(title.number) via libdvdcss...")

        guard FileManager.default.createFile(atPath: path, contents: nil),
              let output = FileHandle(forWritingAtPath: path) else {
            throw MediaRipperError.fileCreationFailed
        }
        defer { try? output.close() }

        var sectorOffset: UInt32 = 0
        var skippedSectors = 0
        while sectorOffset < totalSectors {
            if shouldCancel { throw MediaRipperError.cancelled }

            let sectorsToRead = Int(min(UInt32(1024), totalSectors - sectorOffset))
            let startSector = title.startSector + sectorOffset

            var data = (try? dvdDecryptor!.readAndDecryptSectors(
                startSector: startSector, sectorCount: sectorsToRead)) ?? Data()
            let readSectors = data.count / DVDCSS_BLOCK_SIZE
            if readSectors < sectorsToRead {
                // Failed or short read: recover the rest of the chunk sector by sector.
                data = data.prefix(readSectors * DVDCSS_BLOCK_SIZE)
                for sector in readSectors..<sectorsToRead {
                    if shouldCancel { throw MediaRipperError.cancelled }
                    let single = try? dvdDecryptor!.readAndDecryptSectors(
                        startSector: startSector + UInt32(sector), sectorCount: 1)
                    if let single = single, single.count == DVDCSS_BLOCK_SIZE {
                        data.append(single)
                    } else {
                        skippedSectors += 1
                        guard skippedSectors <= Self.maxSkippedSectorsPerTitle else {
                            throw DVDError.invalidSector
                        }
                        data.append(Data(count: DVDCSS_BLOCK_SIZE))
                    }
                }
            }

            try output.write(contentsOf: data)
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

        if skippedSectors > 0 {
            let message = "Title \(title.number): \(skippedSectors) unreadable sector(s) replaced with blanks "
                + "(expect a brief glitch)."
            Logger.shared.log(message, level: .warning, category: .dvdRipping)
            delegate?.mediaRipperDidUpdateStatus(message)
        }
    }

    /// ffmpeg arguments to encode a decrypted DVD title file.
    private func dvdEncodeArguments(for title: DVDTitle, input: String, output: String,
                                    configuration: RippingConfiguration) -> [String] {
        // Large probe window: audio/subtitle substreams in MPEG-PS appear
        // sporadically, and ffmpeg's default quick scan misses them entirely.
        var args = ["-probesize", "200M", "-analyzeduration", "120M",
                    "-i", input,
                    "-map", "0:v:0", "-map", "0:a?"]
        if configuration.includeSubtitles { args.append(contentsOf: ["-map", "0:s?"]) }
        args.append(contentsOf: videoEncoderArguments(for: configuration))
        if configuration.autoDeinterlace {
            // deint=interlaced only touches frames flagged interlaced (NTSC DVDs);
            // progressive content passes through untouched
            args.append(contentsOf: ["-vf", "bwdif=mode=send_frame:parity=auto:deint=interlaced"])
        }
        args.append(contentsOf: audioEncoderArguments(for: configuration.audioCodec))
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
        args.append(contentsOf: ["-f", "matroska", "-y", output])
        return args
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
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()  // drain before waiting: a full pipe blocks the child
            process.waitUntilExit()
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
            let data = pipe.fileHandleForReading.readDataToEndOfFile()  // drain before waiting: a full pipe blocks the child
            process.waitUntilExit()

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
