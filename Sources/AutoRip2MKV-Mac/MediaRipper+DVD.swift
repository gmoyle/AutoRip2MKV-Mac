import Foundation

// MARK: - DVD Ripping Implementation

extension MediaRipper {

    func performDVDRipping(dvdPath: String, configuration: RippingConfiguration) throws {
        // Step 1: Parse DVD structure
        delegate?.mediaRipperDidUpdateStatus("Analyzing DVD structure...")
        dvdParser = DVDStructureParser(dvdPath: dvdPath)
        let titles = try dvdParser!.parseDVDStructure()

        guard !titles.isEmpty else {
            throw MediaRipperError.noTitlesFound
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

        // Step 3: Initialize DVD decryptor
        delegate?.mediaRipperDidUpdateStatus("Initializing DVD CSS decryption...")
        let devicePath = findDVDDevice(dvdPath: dvdPath)
        guard let devicePath = devicePath else {
            throw MediaRipperError.deviceNotFound
        }
        dvdDecryptor = DVDDecryptor(devicePath: devicePath)
        try dvdDecryptor!.initializeDevice()

        // Step 4: Determine which titles to rip
        let titlesToRip = filterTitlesToRip(titles: titles, selectedTitles: configuration.selectedTitles)
        delegate?.mediaRipperDidUpdateStatus("Titles to rip: \(titlesToRip.map({ $0.number }))")
        delegate?.mediaRipperDidUpdateProgress(0.0, currentItem: nil, totalItems: titlesToRip.count)

        // Step 5: Rip each title to organized directory
        for (index, title) in titlesToRip.enumerated() {
            if shouldCancel {
                throw MediaRipperError.cancelled
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

        // For now, try to read VOB files directly instead of sector-based decryption
        if !title.vobFiles.isEmpty {
            return try extractFromVOBFiles(title: title, outputPath: tempFilePath)
        }

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
            delegate?.mediaRipperDidUpdateProgress(
                progress * 0.5, currentItem: .dvdTitle(title), totalItems: 1
            ) // 50% for extraction
        }

        return tempFilePath
    }
    
    /// Extract from VOB files directly (fallback method)
    private func extractFromVOBFiles(title: DVDTitle, outputPath: String) throws -> String {
        delegate?.mediaRipperDidUpdateStatus("Starting VOB file extraction for title \(title.number)...")
        delegate?.mediaRipperDidUpdateStatus("Output path: \(outputPath)")
        
        guard let outputHandle = FileHandle(forWritingAtPath: outputPath) ??
              createFileAndGetHandle(at: outputPath) else {
            delegate?.mediaRipperDidUpdateStatus("ERROR: Failed to create output file at \(outputPath)")
            throw MediaRipperError.fileCreationFailed
        }

        defer { outputHandle.closeFile() }

        // Calculate total size
        var totalSize: Int64 = 0
        for vobFile in title.vobFiles {
            if let fileSize = (try? FileManager.default.attributesOfItem(atPath: vobFile)[.size] as? Int64) {
                totalSize += fileSize
                delegate?.mediaRipperDidUpdateStatus("VOB file \(vobFile): \(fileSize) bytes")
            } else {
                delegate?.mediaRipperDidUpdateStatus("WARNING: Could not get size of VOB file \(vobFile)")
            }
        }
        
        delegate?.mediaRipperDidUpdateStatus("Total extraction size: \(totalSize) bytes (\(Double(totalSize) / 1024.0 / 1024.0 / 1024.0) GB)")

        var totalBytesRead: Int64 = 0

        // Read all VOB files for this title
        for (index, vobFile) in title.vobFiles.enumerated() {
            if shouldCancel {
                throw MediaRipperError.cancelled
            }

            delegate?.mediaRipperDidUpdateStatus("Reading VOB file \(index + 1) of \(title.vobFiles.count): \(vobFile)")

            guard FileManager.default.fileExists(atPath: vobFile) else {
                delegate?.mediaRipperDidUpdateStatus("ERROR: VOB file does not exist: \(vobFile)")
                continue
            }
            
            guard let inputHandle = FileHandle(forReadingAtPath: vobFile) else {
                delegate?.mediaRipperDidUpdateStatus("ERROR: Cannot open VOB file for reading: \(vobFile)")
                continue // Skip if we can't read the file
            }

            defer { inputHandle.closeFile() }

            // Read in chunks
            let chunkSize = 1024 * 1024 // 1MB chunks
            var filePosition: Int64 = 0
            
            while !shouldCancel {
                let data = inputHandle.readData(ofLength: chunkSize)
                if data.isEmpty {
                    break // End of file
                }

                outputHandle.write(data)
                totalBytesRead += Int64(data.count)
                filePosition += Int64(data.count)
                
                // Update progress every 10MB
                if totalBytesRead % (10 * 1024 * 1024) == 0 {
                    let progress = Double(totalBytesRead) / Double(totalSize)
                    delegate?.mediaRipperDidUpdateStatus("Extracted \(totalBytesRead / 1024 / 1024) MB of \(totalSize / 1024 / 1024) MB (\(Int(progress * 100))%)")
                    delegate?.mediaRipperDidUpdateProgress(
                        progress * 0.5, currentItem: .dvdTitle(title), totalItems: 1
                    ) // 50% for extraction
                }
            }
            
            delegate?.mediaRipperDidUpdateStatus("Completed VOB file \(index + 1): \(filePosition) bytes read")
        }
        
        delegate?.mediaRipperDidUpdateStatus("VOB extraction completed. Total bytes: \(totalBytesRead)")
        
        // Final progress update
        delegate?.mediaRipperDidUpdateProgress(0.5, currentItem: .dvdTitle(title), totalItems: 1)

        return outputPath
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
            // Return all titles that are longer than 1 minute (to filter out menus and very short clips)
            return titles.filter { $0.duration >= 60.0 }
        } else {
            // Return only selected titles
            return titles.filter { selectedTitles.contains($0.number) }
        }
    }

    /// Determine appropriate title name based on content and position
    private func determineTitleName(title: DVDTitle, titleIndex: Int, totalTitles: Int) -> String {
        // Determine if this is likely the main movie or bonus content
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
