import Foundation

// MARK: - DVD Ripping Implementation

extension MediaRipper {
    
    func performDVDRipping(dvdPath: String, configuration: RippingConfiguration) throws {
        // Step 1: Parse DVD structure
        delegate?.ripperDidUpdateStatus("Analyzing DVD structure...")
        dvdParser = DVDStructureParser(dvdPath: dvdPath)
        let titles = try dvdParser!.parseDVDStructure()
        
        guard !titles.isEmpty else {
            throw MediaRipperError.noTitlesFound
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
        
        // Step 3: Initialize DVD decryptor
        delegate?.ripperDidUpdateStatus("Initializing DVD CSS decryption...")
        let devicePath = findDVDDevice(dvdPath: dvdPath)
        dvdDecryptor = DVDDecryptor(devicePath: devicePath)
        try dvdDecryptor!.initializeDevice()
        
        // Step 4: Determine which titles to rip
        let titlesToRip = filterTitlesToRip(titles: titles, selectedTitles: configuration.selectedTitles)
        delegate?.ripperDidUpdateProgress(0.0, currentItem: nil, totalItems: titlesToRip.count)
        
        // Step 5: Rip each title to organized directory
        for (index, title) in titlesToRip.enumerated() {
            if shouldCancel {
                throw MediaRipperError.cancelled
            }
            
            delegate?.ripperDidUpdateStatus("Ripping DVD title \(title.number) (\(title.formattedDuration))...")
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
            let encryptedData = try dvdDecryptor!.readSectors(startSector: startSector, sectorCount: sectorsToRead)
            
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
    
    private func createFileAndGetHandle(at path: String) -> FileHandle? {
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
