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

        // Step 2: Extract movie name and create organized directory
        delegate?.mediaRipperDidUpdateStatus("Analyzing disc information...")
        let movieName = extractMovieName(from: dvdPath, mediaType: currentMediaType)
        let organizedOutputDirectory = createOrganizedOutputDirectory(
            baseDirectory: configuration.outputDirectory,
            mediaType: currentMediaType,
            movieName: movieName
        )

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

        // Step 5: Rip each title to organized directory with error recovery
        for (index, title) in titlesToRip.enumerated() {
            if shouldCancel {
                let error = MediaRipperError.cancelled
                Logger.shared.logError(error, context: "Ripping cancelled by user")
                delegate?.mediaRipperDidFail(with: error)
                throw error
            }

            delegate?.mediaRipperDidUpdateStatus("Ripping DVD title \(title.number) (\(title.formattedDuration))...")
            try ripDVDTitle(title, configuration: configuration, outputDirectory: organizedOutputDirectory,
                           titleIndex: index, totalTitles: titlesToRip.count)
        }
    }

    private func ripDVDTitle(_ title: DVDTitle, configuration: RippingConfiguration, outputDirectory: String, titleIndex: Int, totalTitles: Int) throws {
        // Get title key for decryption
        let titleKey = try dvdDecryptor!.getTitleKey(titleNumber: title.number, startSector: title.startSector)

        // Create intelligent output filename
        let titleName = determineTitleName(title: title, titleIndex: titleIndex, totalTitles: totalTitles)
        let outputFileName = "\(titleName)_\(title.formattedDuration.replacingOccurrences(of: ":", with: "-")).mkv"
        let outputPath = outputDirectory.appending("/\(outputFileName)")

        // Extract and decrypt video data
        delegate?.mediaRipperDidUpdateStatus("Extracting video data for title \(title.number)...")
        let tempVideoFile = try extractAndDecryptDVDTitle(title, titleKey: titleKey)
        delegate?.mediaRipperDidUpdateStatus("Extracted video data to: \(tempVideoFile)")

        // Convert to MKV
        delegate?.mediaRipperDidUpdateStatus("Converting to MKV format...")
        try convertToMKV(
            inputFile: tempVideoFile,
            outputFile: outputPath,
            mediaItem: .dvdTitle(title),
            configuration: configuration,
            itemIndex: titleIndex,
            totalItems: totalTitles
        )
        delegate?.mediaRipperDidUpdateStatus("Conversion complete: \(outputPath)")

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
        let totalSectors = title.sectors > 0 ? title.sectors : UInt32(1)
        let totalSize = Int64(totalSectors) * 2048

        delegate?.mediaRipperDidUpdateStatus("Reading \(totalSectors) sectors for title \(title.number) via libdvdcss...")

        // Read and decrypt via libdvdcss in 1024-sector chunks
        var sectorOffset: UInt32 = 0
        while sectorOffset < totalSectors {
            if shouldCancel {
                throw MediaRipperError.cancelled
            }

            let sectorsToRead = Int(min(UInt32(1024), totalSectors - sectorOffset))
            let startSector = title.startSector + sectorOffset

            let decryptedData = try dvdDecryptor!.readAndDecryptSectors(
                startSector: startSector, sectorCount: sectorsToRead
            )

            if decryptedData.isEmpty {
                delegate?.mediaRipperDidUpdateStatus("Warning: no data at sector \(startSector)")
                sectorOffset += UInt32(sectorsToRead)
                continue
            }

            outputHandle.write(decryptedData)
            totalBytesRead += Int64(decryptedData.count)
            sectorOffset += UInt32(sectorsToRead)

            let progress = Double(totalBytesRead) / Double(totalSize)
            delegate?.mediaRipperDidUpdateProgress(
                progress * 0.5, currentItem: .dvdTitle(title), totalItems: 1
            )
        }

        delegate?.mediaRipperDidUpdateStatus("Extraction complete: \(totalBytesRead) bytes")
        return tempFilePath
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
