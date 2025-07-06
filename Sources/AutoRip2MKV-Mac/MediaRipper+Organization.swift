import Foundation
import AVFoundation

// MARK: - MediaRipper Organization Extension
extension MediaRipper {

    // MARK: - Disc Type Detection

    /// Detect if a Blu-ray disc is Ultra HD (4K)
    func isUltraHDBluRay(bdmvPath: String) -> Bool {
        // Check for 4K indicators in BDMV structure
        let indexPath = bdmvPath.appending("/index.bdmv")
        _ = bdmvPath.appending("/MovieObject.bdmv") // Future use for 4K detection

        guard FileManager.default.fileExists(atPath: indexPath) else { return false }

        do {
            let indexData = try Data(contentsOf: URL(fileURLWithPath: indexPath))

            // Look for UHD/4K indicators in the index file
            // UHD Blu-rays typically have specific resolution markers
            let searchPatterns: [Data] = [
                Data("UHD".utf8),
                Data("3840".utf8), // 4K width
                Data("2160".utf8), // 4K height
                Data([0x0F, 0x00]), // UHD resolution marker
            ]

            for pattern in searchPatterns {
                if indexData.range(of: pattern) != nil {
                    return true
                }
            }
        } catch {
            // If we can't read the file, fall back to directory structure
        }

        // Check for UHD-specific directory structure
        let certificatePath = bdmvPath.appending("/CERTIFICATE/id.bdmv")
        return FileManager.default.fileExists(atPath: certificatePath)
    }

    /// Detect if a DVD is Ultra HD DVD (rare format)
    func isUltraHDDVD(videoTSPath: String) -> Bool {
        // Ultra HD DVD is a rare format, check for HD indicators
        let vmgiPath = videoTSPath.appending("/VIDEO_TS.IFO")

        guard FileManager.default.fileExists(atPath: vmgiPath) else { return false }

        do {
            let vmgiData = try Data(contentsOf: URL(fileURLWithPath: vmgiPath))

            // Look for HD resolution indicators
            // Ultra HD DVDs would have higher resolution markers
            let hdPatterns: [Data] = [
                Data([0x04, 0x00]), // HD resolution marker
                Data([0x05, 0x00]), // Enhanced resolution marker
            ]

            for pattern in hdPatterns {
                if vmgiData.range(of: pattern) != nil {
                    return true
                }
            }
        } catch {
            return false
        }

        return false
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
        case .dvd, .ultraHDDVD:
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

    // MARK: - Directory Organization

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
            "ripper_version": "AutoRip2MKV-Mac 1.0"
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
