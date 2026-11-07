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

        // Step 3: Determine which titles to rip
        // Route after the encodes land (see ConversionQueue.performEncodes);
        // all of the disc's titles inform the movie-vs-TV classification.
        routeAfterEncodes = PendingRoute(
            folderPath: organizedOutputDirectory,
            discName: (dvdPath as NSString).lastPathComponent,
            discIdentity: DiscIdentity.compute(forDiscAt: dvdPath),
            titleDurationsSeconds: titles.map { Int($0.duration) })
        let titlesToRip = filterTitlesToRip(titles: titles, selectedTitles: configuration.selectedTitles,
                                            ripBonusFeatures: configuration.ripBonusFeatures)
        delegate?.mediaRipperDidUpdateStatus("Titles to rip: \(titlesToRip.map({ $0.number }))")
        delegate?.mediaRipperDidUpdateProgress(0.0, currentItem: nil, totalItems: titlesToRip.count)

        // Step 4: Stage each title on local disk at full drive speed, then queue
        // its encode. Encoding straight from the disc throttled the drive to
        // encoder speed and kept the disc — and the next job — waiting.
        // A retry starts over from the first title; drop anything a failed earlier
        // attempt staged.
        discardPendingEncodes()
        let ffmpegPath = try getFFmpegPath()
        try preflightStagingSpace(for: titlesToRip)

        isFeedingDisc = true
        defer { isFeedingDisc = false }

        let plans = titlesToRip.enumerated().map { index, title in
            planDVDTitle(title, index: index, totalTitles: titlesToRip.count,
                         configuration: configuration, outputDirectory: organizedOutputDirectory)
        }

        // MakeMKV first: it follows the disc's navigation (seamless branching,
        // interleaved angles, cell order) that a raw sector read can't, and
        // remuxes the title without re-encoding. Titles it can't stage fall
        // back to the libdvdcss reader below.
        var staged: [Int: String] = [:]   // plan index -> staged MKV from MakeMKV
        if SettingsManager.shared.useMakeMKVForDVD && MakeMKVBackend.isInstalled {
            do {
                staged = try stageDVDTitlesWithMakeMKV(dvdPath: dvdPath, plans: plans)
            } catch let error as MakeMKVBackend.MakeMKVError {
                switch error {
                case .notInstalled:
                    Logger.shared.logError(error, context: "MakeMKV unavailable for DVD; using libdvdcss",
                                           category: .dvdRipping)
                    delegate?.mediaRipperDidUpdateStatus("MakeMKV unavailable — reading the DVD directly")
                default:
                    throw error
                }
            }
        }

        for plan in plans {
            if shouldCancel {
                let error = MediaRipperError.cancelled
                Logger.shared.logError(error, context: "Ripping cancelled by user")
                throw error
            }
            let title = plan.title
            let sourcePath: String
            if let mkv = staged[plan.index] {
                sourcePath = mkv
            } else {
                sourcePath = encodingStagingPath(for: plan.outputPath + ".vob")
                try? FileManager.default.removeItem(atPath: sourcePath)
                delegate?.mediaRipperDidUpdateStatus(
                    "Ripping title \(title.number) (\(title.formattedDuration)) → \(plan.outputFileName)...")
                try readTitleWithLibdvdcss(title, dvdPath: dvdPath, to: sourcePath,
                                           titleIndex: plan.index, totalTitles: plans.count)
            }
            pendingEncodes.append(PendingEncode(
                ffmpegPath: ffmpegPath,
                arguments: dvdEncodeArguments(for: title, input: sourcePath, output: plan.stagingPath,
                                              configuration: configuration, ffmpegPath: ffmpegPath,
                                              labelLanguagesFromIFO: staged[plan.index] == nil),
                sourcePath: sourcePath, outputPath: plan.outputPath, stagingPath: plan.stagingPath,
                titleNumber: title.number, mediaItem: .dvdTitle(title),
                itemIndex: plan.index, totalItems: plans.count))
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

    /// Sectors in the title set's title VOBs (VTS_xx_1.VOB onward), from their
    /// sizes, or nil when they aren't known.
    private func vobSetSectorCount(of title: DVDTitle) -> UInt32? {
        guard !title.vobFiles.isEmpty else { return nil }
        let totalBytes = title.vobFiles.reduce(Int64(0)) { acc, path in
            acc + ((try? FileManager.default.attributesOfItem(atPath: path)[.size] as? Int64) ?? 0)
        }
        return totalBytes > 0 ? UInt32(totalBytes / 2048) : nil
    }

    /// The sector ranges to read for `title`, relative to its first title VOB.
    /// A title set often holds several titles (here: the movie plus extras), so
    /// reading the whole VOB set would append them all to the movie. Uses the
    /// title's own cells; falls back to the whole set when the cells are missing
    /// or don't fit inside it.
    func readRanges(of title: DVDTitle) -> [ClosedRange<UInt32>] {
        let vobSectors = vobSetSectorCount(of: title)
        if !title.cellRanges.isEmpty,
           vobSectors.map({ count in title.cellRanges.allSatisfy { $0.upperBound < count } }) ?? true {
            return title.cellRanges
        }
        let total = vobSectors ?? max(title.sectors, 1)
        if !title.cellRanges.isEmpty {
            Logger.shared.log("Title \(title.number): cell ranges exceed the VOB set (\(total) sectors); "
                              + "reading the whole title set", level: .warning, category: .dvdRipping)
        }
        return [0...(total - 1)]
    }

    /// Sectors that will be read for `title`.
    private func sectorCount(of title: DVDTitle) -> UInt32 {
        readRanges(of: title).reduce(UInt32(0)) { $0 + UInt32($1.count) }
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

    /// Absolute disc sector where `title`'s video data begins: the physical
    /// location of its first title VOB (VTS_xx_1.VOB), asked of the mounted
    /// filesystem. The VIDEO_TS.IFO title table's sector is the *title set's*
    /// start (its IFO, not its video) and is relative to the video manager, so
    /// on discs where VIDEO_TS isn't near sector 0 it points into filesystem
    /// metadata. A VTS's VOB files are stored contiguously, so reading
    /// `sectorCount(of:)` sectors from here covers all of them.
    func discStartSector(of title: DVDTitle) throws -> UInt32 {
        guard let firstVOB = title.vobFiles.first,
              let sector = Self.physicalStartSector(ofFile: firstVOB) else {
            Logger.shared.log("No disc location for title \(title.number) (VOBs: \(title.vobFiles))",
                              level: .error, category: .general)
            throw DVDError.titleLocationUnknown
        }
        return sector
    }

    /// Device sector of byte 0 of `path` on its volume (F_LOG2PHYS_EXT), or nil.
    static func physicalStartSector(ofFile path: String) -> UInt32? {
        let fd = open(path, O_RDONLY)
        guard fd >= 0 else { return nil }
        defer { close(fd) }
        var mapping = log2phys()
        mapping.l2p_contigbytes = Int64(DVDCSS_BLOCK_SIZE)  // in: bytes to map
        mapping.l2p_devoffset = 0                           // in: file offset
        guard fcntl(fd, F_LOG2PHYS_EXT, &mapping) != -1, mapping.l2p_devoffset >= 0 else { return nil }
        return UInt32(mapping.l2p_devoffset / Int64(DVDCSS_BLOCK_SIZE))
    }

    /// True when `data` starts with an MPEG-2 program stream pack header.
    static func isMPEGPackHeader(_ data: Data) -> Bool {
        data.count >= 4 && data.prefix(4).elementsEqual([0x00, 0x00, 0x01, 0xBA])
    }

    /// Most unreadable sectors tolerated per title before giving up (8 MB, a few
    /// seconds of video). Past that the disc is too damaged for a usable rip.
    static let maxSkippedSectorsPerTitle = 4096

    /// Read and decrypt `title` into the file at `path`.
    ///
    /// Ordinary cells are read straight through in large chunks. Interleaved
    /// cells (seamless branching, multi-angle) hold several versions' VOBUs
    /// woven together, so they're walked VOBU by VOBU, following each
    /// navigation pack's next-VOBU pointer, which skips the other versions'
    /// units — what a DVD player does. Reading them straight through would
    /// put every version back to back in one file.
    ///
    /// Unreadable sectors (scratches) are re-read one at a time and, if they
    /// still fail, written as zeros — ffmpeg resyncs at the next pack header — so
    /// a small scratch costs a glitch instead of the whole disc.
    func readDVDTitle(_ title: DVDTitle, from discStart: UInt32, to path: String,
                      titleIndex: Int, totalTitles: Int) throws {
        let ranges = readRanges(of: title)
        let totalSectors = sectorCount(of: title)
        delegate?.mediaRipperDidUpdateStatus("Reading \(totalSectors) sectors for title \(title.number) via libdvdcss...")

        guard FileManager.default.createFile(atPath: path, contents: nil),
              let output = FileHandle(forWritingAtPath: path) else {
            throw MediaRipperError.fileCreationFailed
        }
        defer { try? output.close() }

        var skippedSectors = 0
        var rangesDone: UInt32 = 0      // sectors spanned by finished ranges
        var lastReported: UInt32 = 0
        func reportProgress(_ position: UInt32) {
            let done = rangesDone + position
            guard done / 16384 != lastReported / 16384 || done >= totalSectors else { return }
            lastReported = done
            let titleFraction = min(Double(done) / Double(max(totalSectors, 1)), 1)
            let overall = (Double(titleIndex) + titleFraction) / Double(max(totalTitles, 1))
            DispatchQueue.main.async {
                self.delegate?.mediaRipperDidUpdateProgress(overall, currentItem: .dvdTitle(title),
                                                            totalItems: totalTitles)
            }
        }

        /// Copy `sectors` from `first` (VOBS-relative) to the output in chunks.
        func copySectors(from first: UInt32, through last: UInt32, progressBase: UInt32) throws {
            var offset = first
            while offset <= last {
                if shouldCancel { throw MediaRipperError.cancelled }
                let count = Int(min(UInt32(1024), last - offset + 1))
                let data = try readSectorsRecovering(at: discStart + offset, count: count,
                                                     skipped: &skippedSectors)
                try output.write(contentsOf: data)
                offset += UInt32(count)
                reportProgress(offset - progressBase)
            }
        }

        var interleavedVOBUs = 0
        for range in ranges {
            // Every cell starts on a VOBU, which opens with an MPEG-PS pack
            // header. Anything else means we're reading the wrong part of the
            // disc: fail now rather than stage gigabytes of filesystem data and
            // zeros as "the movie".
            let head = try readSectorsRecovering(at: discStart + range.lowerBound, count: 1,
                                                 skipped: &skippedSectors)
            guard Self.isMPEGPackHeader(head) else {
                throw DVDError.notVideoData(sector: discStart + range.lowerBound)
            }

            if title.interleavedRanges.contains(range) {
                var vobu = range.lowerBound
                var nav = head
                while vobu <= range.upperBound {
                    if shouldCancel { throw MediaRipperError.cancelled }
                    guard let info = Self.vobuNavigation(navPack: nav) else {
                        // Damaged or missing nav pack: no pointer to follow, so
                        // read the rest of the cell as-is.
                        Logger.shared.log("Title \(title.number): no VOBU navigation at sector \(vobu); "
                                          + "reading the rest of the cell straight through",
                                          level: .warning, category: .dvdRipping)
                        try copySectors(from: vobu, through: range.upperBound, progressBase: range.lowerBound)
                        break
                    }
                    let vobuLast = min(vobu &+ info.lastSectorOffset, range.upperBound)
                    try output.write(contentsOf: nav)
                    if vobuLast > vobu {
                        try copySectors(from: vobu + 1, through: vobuLast, progressBase: range.lowerBound)
                    }
                    interleavedVOBUs += 1
                    guard let step = info.nextVOBUOffset, step > 0 else { break }  // end of cell
                    vobu += step
                    if vobu <= range.upperBound {
                        nav = try readSectorsRecovering(at: discStart + vobu, count: 1, skipped: &skippedSectors)
                    }
                }
            } else {
                try output.write(contentsOf: head)
                if range.upperBound > range.lowerBound {
                    try copySectors(from: range.lowerBound + 1, through: range.upperBound,
                                    progressBase: range.lowerBound)
                }
            }
            rangesDone += UInt32(range.count)
            reportProgress(0)
        }

        if interleavedVOBUs > 0 {
            Logger.shared.log("Title \(title.number): followed \(interleavedVOBUs) VOBUs through "
                              + "\(title.interleavedRanges.count) interleaved cell(s)",
                              level: .info, category: .dvdRipping)
        }
        if skippedSectors > 0 {
            let message = "Title \(title.number): \(skippedSectors) unreadable sector(s) replaced with blanks "
                + "(expect a brief glitch)."
            Logger.shared.log(message, level: .warning, category: .dvdRipping)
            delegate?.mediaRipperDidUpdateStatus(message)
        }
    }

    /// Read `count` sectors at absolute `start`; a failed or short read is
    /// retried sector by sector, and sectors that still fail become zeros (up
    /// to `maxSkippedSectorsPerTitle` in total).
    private func readSectorsRecovering(at start: UInt32, count: Int, skipped: inout Int) throws -> Data {
        var data = (try? dvdDecryptor!.readAndDecryptSectors(startSector: start, sectorCount: count)) ?? Data()
        let readSectors = data.count / DVDCSS_BLOCK_SIZE
        guard readSectors < count else { return data }
        data = data.prefix(readSectors * DVDCSS_BLOCK_SIZE)
        for sector in readSectors..<count {
            if shouldCancel { throw MediaRipperError.cancelled }
            let single = try? dvdDecryptor!.readAndDecryptSectors(startSector: start + UInt32(sector), sectorCount: 1)
            if let single = single, single.count == DVDCSS_BLOCK_SIZE {
                data.append(single)
            } else {
                skipped += 1
                guard skipped <= Self.maxSkippedSectorsPerTitle else { throw DVDError.invalidSector }
                data.append(Data(count: DVDCSS_BLOCK_SIZE))
            }
        }
        return data
    }

    /// Navigation from a VOBU's nav pack (its first sector): the offset of the
    /// VOBU's last sector, and the offset to the next VOBU of this program
    /// (nil at the end of the cell). Offsets are relative to the nav pack.
    /// Nil if the sector isn't a nav pack. Pure, for tests.
    ///
    /// Layout: PCI packet at 0x26, DSI packet at 0x400 with its data at 0x407.
    /// DSI general info: VOBU_EA at +8. VOBU search info's NEXT_VOBU at +314
    /// (after DSI_GI 32, SML_PBI 148, SML_AGLI 54, NEXT_VIDEO 4, FWDA 76 bytes);
    /// its low 30 bits are the offset, 0x3FFFFFFF meaning end of cell.
    static func vobuNavigation(navPack: Data) -> (lastSectorOffset: UInt32, nextVOBUOffset: UInt32?)? {
        let base = navPack.startIndex
        guard navPack.count >= DVDCSS_BLOCK_SIZE, isMPEGPackHeader(navPack) else { return nil }
        let pci: [UInt8] = [0x00, 0x00, 0x01, 0xBF]
        guard navPack[(base + 0x26)..<(base + 0x2A)].elementsEqual(pci), navPack[base + 0x2C] == 0x00,
              navPack[(base + 0x400)..<(base + 0x404)].elementsEqual(pci), navPack[base + 0x406] == 0x01 else {
            return nil
        }
        func u32(_ offset: Int) -> UInt32 {
            (0..<4).reduce(UInt32(0)) { $0 << 8 | UInt32(navPack[base + offset + $1]) }
        }
        let dsi = 0x407
        let next = u32(dsi + 314) & 0x3FFF_FFFF
        return (u32(dsi + 8), next == 0x3FFF_FFFF ? nil : next)
    }

    /// ffmpeg arguments to encode a decrypted DVD title file. A MakeMKV-staged
    /// MKV already carries track languages (and MakeMKV may drop or reorder
    /// tracks), so IFO-order labels are only applied to raw VOB input.
    func dvdEncodeArguments(for title: DVDTitle, input: String, output: String,
                            configuration: RippingConfiguration, ffmpegPath: String,
                            labelLanguagesFromIFO: Bool = true) -> [String] {
        // Large probe window: audio/subtitle substreams in MPEG-PS appear
        // sporadically, and ffmpeg's default quick scan misses them entirely.
        var args = ["-probesize", "200M", "-analyzeduration", "120M"]
        // Seamless branching: where the program switches between interleaved
        // versions, timestamps jump ~4 s (The Goonies: 13 jumps, 103 s). The
        // content is continuous, so let ffmpeg's discontinuity correction
        // (MPEG-PS, audio/video) close any jump over 1 s instead of its default
        // 10 s. MakeMKV output is already continuous.
        if labelLanguagesFromIFO && !title.interleavedRanges.isEmpty {
            args.append(contentsOf: ["-dts_delta_threshold", "1"])
        }
        args.append(contentsOf: ["-i", input,
                                 "-map", "0:v:0", "-map", "0:a?"])
        if configuration.includeSubtitles { args.append(contentsOf: ["-map", "0:s?"]) }
        args.append(contentsOf: videoEncoderArguments(for: configuration, ffmpegPath: ffmpegPath))
        if configuration.autoDeinterlace {
            // deint=interlaced only touches frames flagged interlaced (NTSC DVDs);
            // progressive content passes through untouched
            args.append(contentsOf: ["-vf", "bwdif=mode=send_frame:parity=auto:deint=interlaced"])
        }
        args.append(contentsOf: audioEncoderArguments(for: configuration.audioCodec))
        if configuration.includeSubtitles { args.append(contentsOf: ["-c:s", "copy"]) }
        if configuration.includeChapters  { args.append(contentsOf: ["-map_chapters", "0"]) }

        // Label tracks with languages from the VTS IFO (stream order)
        for (index, lang) in title.audioLanguages.enumerated() where labelLanguagesFromIFO && !lang.isEmpty {
            args.append(contentsOf: ["-metadata:s:a:\(index)", "language=\(iso639_2(from: lang))"])
        }
        if configuration.includeSubtitles && labelLanguagesFromIFO {
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
    func findRawDVDDevice(dvdPath: String) -> String? {
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

    func filterTitlesToRip(titles: [DVDTitle], selectedTitles: [Int],
                           ripBonusFeatures: Bool) -> [DVDTitle] {
        if selectedTitles.isEmpty {
            // Use intelligent filtering when no titles explicitly selected
            if SettingsManager.shared.intelligentTitleSelection {
                let analyzer = TitleAnalyzer()
                var rules = SettingsManager.shared.getTitleFilteringRules()
                rules.autoSelectMainFeature = !ripBonusFeatures
                let filtered = analyzer.filterDVDTitles(titles, rules: rules)

                Logger.shared.log(
                    "Intelligent title filtering: \(titles.count) titles → \(filtered.count) selected"
                        + (ripBonusFeatures ? "" : " (main feature only; bonus features off)"),
                    level: .info,
                    category: .general
                )

                return filtered
            } else {
                // Fallback to basic duration filter; without bonus features, just
                // the longest title (the movie).
                let candidates = titles.filter { $0.duration >= 60.0 }
                if !ripBonusFeatures, let longest = candidates.max(by: { $0.duration < $1.duration }) {
                    return [longest]
                }
                return candidates
            }
        } else {
            // Return only explicitly selected titles
            return titles.filter { selectedTitles.contains($0.number) }
        }
    }

    /// Determine appropriate title name based on content and position
    func determineTitleName(title: DVDTitle, titleIndex: Int, totalTitles: Int) -> String {
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
