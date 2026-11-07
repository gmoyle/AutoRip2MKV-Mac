import Foundation
import AVFoundation

// MARK: - MediaRipper Organization Extension
extension MediaRipper {

    // MARK: - Disc Type Detection

    /// Detect if a Blu-ray disc is Ultra HD (4K).
    ///
    /// The BDMV spec versions index.bdmv in its 8-byte header: "INDX0100"/"INDX0200"
    /// for Blu-ray, "INDX0300" for Ultra HD Blu-ray. Scanning the file for byte
    /// patterns ("2160", 0x0F00) or checking for CERTIFICATE/id.bdmv (present on
    /// every AACS disc) misfires on ordinary Blu-rays.
    func isUltraHDBluRay(bdmvPath: String) -> Bool {
        MediaRipper.isUHDIndex(atPath: bdmvPath.appending("/index.bdmv"))
    }

    /// True when the index.bdmv at `indexPath` carries the UHD ("INDX0300") header.
    static func isUHDIndex(atPath indexPath: String) -> Bool {
        guard let handle = FileHandle(forReadingAtPath: indexPath) else { return false }
        defer { try? handle.close() }
        guard let header = try? handle.read(upToCount: 8) else { return false }
        return header == Data("INDX0300".utf8)
    }

    /// Detect if a DVD is "Ultra HD DVD".
    ///
    /// No such standard exists for VIDEO_TS discs (HD DVD uses HVDVD_TS and is
    /// detected separately), so this always returns false. The previous heuristic
    /// matched the bytes 0x0400/0x0500 anywhere in VIDEO_TS.IFO, which is true
    /// of almost every DVD and filed ordinary rips under "Ultra_HD_DVD".
    func isUltraHDDVD(videoTSPath: String) -> Bool {
        false
    }

    // MARK: - Movie Name Extraction

    /// Extract movie name from disc
    func extractMovieName(from mediaPath: String, mediaType: MediaType) -> String {
        // Try multiple sources for movie name
        if let volumeName = getVolumeLabel(path: mediaPath), !isGenericName(volumeName) {
            return sanitizeMovieName(volumeName)
        }

        if let discTitle = extractDiscTitle(from: mediaPath, mediaType: mediaType), !isGenericName(discTitle) {
            return sanitizeMovieName(discTitle)
        }

        // Fallback to generic name with timestamp
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm"
        let timestamp = formatter.string(from: Date())

        return "\(mediaType.folderName.replacingOccurrences(of: "_", with: ""))_\(timestamp)"
    }

    /// Get volume label from mounted disc
    private func getVolumeLabel(path: String) -> String? {
        // Get the mount point of the disc
        let url = URL(fileURLWithPath: path)

        do {
            let resourceValues = try url.resourceValues(forKeys: [.volumeNameKey])
            return resourceValues.volumeName
        } catch {
            return nil
        }
    }

    /// Extract disc title from disc metadata
    private func extractDiscTitle(from mediaPath: String, mediaType: MediaType) -> String? {
        switch mediaType {
        case .dvd, .ultraHDDVD, .hddvd:
            return extractDVDTitle(from: mediaPath)
        case .bluray, .bluray4K:
            return extractBluRayTitle(from: mediaPath)
        case .unknown:
            return nil
        }
    }

    /// Extract title from DVD metadata
    private func extractDVDTitle(from dvdPath: String) -> String? {
        let vmgiPath = dvdPath.appending("/VIDEO_TS/VIDEO_TS.IFO")

        guard FileManager.default.fileExists(atPath: vmgiPath) else { return nil }

        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: vmgiPath))

            // Look for text data that might contain title information
            // DVD titles are often embedded in the IFO files
            if let titleRange = findTitleInData(data) {
                let titleData = data.subdata(in: titleRange)
                if let title = String(data: titleData, encoding: .utf8) {
                    return title.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        } catch {
            return nil
        }

        return nil
    }

    /// Extract title from Blu-ray metadata
    private func extractBluRayTitle(from blurayPath: String) -> String? {
        let metaPath = blurayPath.appending("/BDMV/META/DL")

        // Check for metadata files
        do {
            let metaContents = try FileManager.default.contentsOfDirectory(atPath: metaPath)
            for file in metaContents {
                if file.hasSuffix(".xml") {
                    let xmlPath = metaPath.appending("/\(file)")
                    if let title = extractTitleFromXML(xmlPath) {
                        return title
                    }
                }
            }
        } catch {
            // Metadata directory doesn't exist or can't be read
        }

        return nil
    }

    /// Extract title from Blu-ray XML metadata
    private func extractTitleFromXML(_ xmlPath: String) -> String? {
        do {
            let xmlData = try Data(contentsOf: URL(fileURLWithPath: xmlPath))
            let xmlString = String(data: xmlData, encoding: .utf8) ?? ""

            // Look for title tags in the XML
            let titlePatterns = [
                "<di:name>([^<]+)</di:name>",
                "<title>([^<]+)</title>",
                "<name>([^<]+)</name>"
            ]

            for pattern in titlePatterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                   let match = regex.firstMatch(in: xmlString, range: NSRange(xmlString.startIndex..., in: xmlString)),
                   let titleRange = Range(match.range(at: 1), in: xmlString) {
                    return String(xmlString[titleRange])
                }
            }
        } catch {
            return nil
        }

        return nil
    }

    /// Find title information in binary data
    private func findTitleInData(_ data: Data) -> Range<Int>? {
        // Look for patterns that might indicate title text
        // This is a simplified implementation - real DVD parsing is complex
        let minTitleLength = 3
        let maxTitleLength = 50

        for i in 0..<(data.count - minTitleLength) {
            var textLength = 0
            var hasAlpha = false

            for j in i..<min(i + maxTitleLength, data.count) {
                let byte = data[j]

                if byte >= 32 && byte <= 126 { // Printable ASCII
                    textLength += 1
                    if (byte >= 65 && byte <= 90) || (byte >= 97 && byte <= 122) {
                        hasAlpha = true
                    }
                } else {
                    break
                }
            }

            if textLength >= minTitleLength && hasAlpha {
                return i..<(i + textLength)
            }
        }

        return nil
    }

    /// Check if a name is generic/default
    private func isGenericName(_ name: String) -> Bool {
        let genericNames = [
            "untitled", "unnamed", "dvd", "blu-ray", "bluray", "disc", "movie",
            "dvd_video", "bd_video", "video_ts", "bdmv", "unknown"
        ]

        let lowercaseName = name.lowercased()
        return genericNames.contains { lowercaseName.contains($0) }
    }

    /// Sanitize movie name for file system
    private func sanitizeMovieName(_ name: String) -> String {
        // Remove or replace invalid characters
        let invalidChars = CharacterSet(charactersIn: "/:*?\"<>|\\")
        let sanitized = name.components(separatedBy: invalidChars).joined(separator: "_")

        // Limit length and clean up
        let maxLength = 100
        let trimmed = String(sanitized.prefix(maxLength))

        return trimmed
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "__", with: "_")
    }

    // MARK: - Cover Art Extraction

    /// Extract cover art from Blu-ray disc
    func extractCoverArt(from mediaPath: String, to outputDirectory: String) {
        guard currentMediaType == .bluray || currentMediaType == .bluray4K else { return }

        let bdmvPath = mediaPath.appending("/BDMV")
        let metaPath = bdmvPath.appending("/META/DL")

        do {
            let metaContents = try FileManager.default.contentsOfDirectory(atPath: metaPath)

            for file in metaContents {
                if file.lowercased().hasSuffix(".jpg") || file.lowercased().hasSuffix(".png") {
                    let imagePath = metaPath.appending("/\(file)")
                    let destinationPath = outputDirectory.appending(
                        "/cover.\(URL(fileURLWithPath: file).pathExtension)"
                    )

                    try FileManager.default.copyItem(atPath: imagePath, toPath: destinationPath)
                    return // Use the first image found
                }
            }
        } catch {
            // No cover art found or couldn't copy
        }
    }

    /// Plex-style folder/file base name from the resolved disc title —
    /// filesystem-safe but keeping spaces and parentheses ("Movie (Year)").
    func plexBaseName(from configuration: RippingConfiguration) -> String? {
        guard let name = configuration.plexName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty else { return nil }
        let invalid = CharacterSet(charactersIn: "/:*?\"<>|\\")
        let cleaned = name.components(separatedBy: invalid).joined(separator: "-")
            .trimmingCharacters(in: .whitespaces)
        return cleaned.isEmpty ? nil : cleaned
    }

    // MARK: - Directory Organization

    /// The organized output directory for a rip, honoring the user's "Directory
    /// Structure" setting via [[OutputOrganizer]]. Prefers the resolved Plex title
    /// ("Movie (Year)") when available, otherwise the extracted disc name. This is
    /// the single choke point the DVD / Blu-ray / HD DVD paths share, replacing the
    /// duplicated plex-vs-media-type branches they used to each carry.
    func organizedDirectory(for configuration: RippingConfiguration,
                            mediaType: MediaType,
                            fallbackName: String) -> String {
        // Content type isn't classified until after the rip (ContentRouter), so at
        // this point it's unknown — the By-Media-Type default then uses the
        // media-type folder, preserving the pre-existing layout.
        let displayName = plexBaseName(from: configuration) ?? fallbackName
        let info = OutputOrganizer.parse(displayName: displayName, contentType: .unknown)
        return OutputOrganizer.directory(
            baseDirectory: configuration.outputDirectory,
            info: info,
            mediaTypeFolderName: mediaType.folderName)
    }

    /// Create organized output directory structure
    func createOrganizedOutputDirectory(baseDirectory: String, mediaType: MediaType, movieName: String) -> String {
        let typeDirectory = baseDirectory.appending("/\(mediaType.folderName)")
        let movieDirectory = typeDirectory.appending("/\(movieName)")

        do {
            try FileManager.default.createDirectory(atPath: movieDirectory,
                                                  withIntermediateDirectories: true,
                                                  attributes: nil)
        } catch {
            // Fall back to base directory if creation fails
            return baseDirectory
        }

        return movieDirectory
    }

    /// Create disc information file
    func createDiscInfo(in directory: String, mediaPath: String, mediaType: MediaType, movieName: String) {
        let discInfo: [String: Any] = [
            "movie_name": movieName,
            "media_type": mediaType.folderName,
            "rip_date": ISO8601DateFormatter().string(from: Date()),
            "source_path": mediaPath,
            "ripper_version": "Spindle"
        ]

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: discInfo, options: .prettyPrinted)
            let infoPath = directory.appending("/disc_info.json")
            try jsonData.write(to: URL(fileURLWithPath: infoPath))
        } catch {
            // Info file creation failed, but continue with ripping
        }
    }
}
