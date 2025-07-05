import Foundation

/// Utility class for applying detailed settings during the ripping process
class SettingsUtilities {
    
    static let shared = SettingsUtilities()
    private let settingsManager = SettingsManager.shared
    
    private init() {}
    
    // MARK: - Directory Structure Creation
    
    /// Creates the appropriate directory structure based on user settings
    /// - Parameters:
    ///   - baseOutputPath: The base output directory
    ///   - mediaType: Type of media (movie, tvshow, etc.)
    ///   - metadata: Media metadata for formatting
    /// - Returns: The final output directory path
    func createOutputDirectory(baseOutputPath: String, 
                             mediaType: MediaType, 
                             metadata: MediaMetadata) -> String {
        
        let outputStructureType = settingsManager.outputStructureType
        
        switch outputStructureType {
        case 0: // Flat - All files in output directory
            return baseOutputPath
            
        case 1: // By Media Type - Movies/TV Shows separated
            return createMediaTypeStructure(baseOutputPath: baseOutputPath, 
                                          mediaType: mediaType, 
                                          metadata: metadata)
            
        case 2: // By Year - Organized by release year
            return createYearBasedStructure(baseOutputPath: baseOutputPath, 
                                          metadata: metadata)
            
        case 3: // By Genre - Organized by genre
            return createGenreBasedStructure(baseOutputPath: baseOutputPath, 
                                           metadata: metadata)
            
        case 4: // Custom - Use format strings
            return createCustomStructure(baseOutputPath: baseOutputPath, 
                                       mediaType: mediaType, 
                                       metadata: metadata)
            
        default:
            return createMediaTypeStructure(baseOutputPath: baseOutputPath, 
                                          mediaType: mediaType, 
                                          metadata: metadata)
        }
    }
    
    private func createMediaTypeStructure(baseOutputPath: String, 
                                        mediaType: MediaType, 
                                        metadata: MediaMetadata) -> String {
        switch mediaType {
        case .movie:
            let movieDir = URL(fileURLWithPath: baseOutputPath).appendingPathComponent("Movies")
            let finalDir = movieDir.appendingPathComponent("\(metadata.title) (\(metadata.year))")
            return finalDir.path
            
        case .tvShow:
            var tvDir = URL(fileURLWithPath: baseOutputPath).appendingPathComponent("TV Shows")
            
            if settingsManager.createSeriesDirectory {
                tvDir = tvDir.appendingPathComponent(metadata.seriesName ?? metadata.title)
            }
            
            if settingsManager.createSeasonDirectory, let season = metadata.season {
                tvDir = tvDir.appendingPathComponent("Season \(season)")
            }
            
            return tvDir.path
            
        case .unknown:
            return URL(fileURLWithPath: baseOutputPath).appendingPathComponent("Other").path
        }
    }
    
    private func createYearBasedStructure(baseOutputPath: String, 
                                        metadata: MediaMetadata) -> String {
        let yearDir = URL(fileURLWithPath: baseOutputPath).appendingPathComponent(String(metadata.year))
        return yearDir.appendingPathComponent(metadata.title).path
    }
    
    private func createGenreBasedStructure(baseOutputPath: String, 
                                         metadata: MediaMetadata) -> String {
        let genre = metadata.genre ?? "Unknown"
        let genreDir = URL(fileURLWithPath: baseOutputPath).appendingPathComponent(genre)
        return genreDir.appendingPathComponent(metadata.title).path
    }
    
    private func createCustomStructure(baseOutputPath: String, 
                                     mediaType: MediaType, 
                                     metadata: MediaMetadata) -> String {
        let formatString: String
        
        switch mediaType {
        case .movie:
            formatString = settingsManager.movieDirectoryFormat
        case .tvShow:
            formatString = settingsManager.tvShowDirectoryFormat
        case .unknown:
            formatString = "{title}"
        }
        
        let formattedPath = formatString
            .replacingOccurrences(of: "{title}", with: metadata.title)
            .replacingOccurrences(of: "{year}", with: String(metadata.year))
            .replacingOccurrences(of: "{series}", with: metadata.seriesName ?? metadata.title)
            .replacingOccurrences(of: "{season}", with: metadata.season.map { String($0) } ?? "1")
            .replacingOccurrences(of: "{genre}", with: metadata.genre ?? "Unknown")
        
        return URL(fileURLWithPath: baseOutputPath).appendingPathComponent(formattedPath).path
    }
    
    // MARK: - Bonus Content Organization
    
    /// Creates the appropriate directory for bonus content
    /// - Parameters:
    ///   - mainOutputPath: The main content output directory
    ///   - contentType: Type of bonus content
    /// - Returns: The bonus content directory path
    func createBonusContentDirectory(mainOutputPath: String, 
                                   contentType: BonusContentType) -> String? {
        
        let bonusStructure = settingsManager.bonusContentStructure
        let bonusDirectory = settingsManager.bonusContentDirectory
        
        switch bonusStructure {
        case 0: // Same directory as main content
            return mainOutputPath
            
        case 1: // Separate 'Bonus' subdirectory
            return URL(fileURLWithPath: mainOutputPath).appendingPathComponent("Bonus").path
            
        case 2: // Separate 'Extras' subdirectory
            return URL(fileURLWithPath: mainOutputPath).appendingPathComponent("Extras").path
            
        case 3: // Custom subdirectory name
            return URL(fileURLWithPath: mainOutputPath).appendingPathComponent(bonusDirectory).path
            
        default:
            return URL(fileURLWithPath: mainOutputPath).appendingPathComponent("Bonus").path
        }
    }
    
    /// Determines if a specific type of bonus content should be included
    /// - Parameter contentType: The type of bonus content
    /// - Returns: Whether to include this content type
    func shouldIncludeBonusContent(_ contentType: BonusContentType) -> Bool {
        switch contentType {
        case .bonusFeatures:
            return settingsManager.includeBonusFeatures
        case .commentaries:
            return settingsManager.includeCommentaries
        case .deletedScenes:
            return settingsManager.includeDeletedScenes
        case .makingOf:
            return settingsManager.includeMakingOf
        case .trailers:
            return settingsManager.includeTrailers
        }
    }
    
    // MARK: - File Naming
    
    /// Generates the appropriate filename based on media type and user settings
    /// - Parameters:
    ///   - mediaType: Type of media
    ///   - metadata: Media metadata
    ///   - codec: Video codec used
    ///   - resolution: Video resolution
    /// - Returns: The formatted filename
    func generateFileName(mediaType: MediaType, 
                         metadata: MediaMetadata, 
                         codec: String? = nil, 
                         resolution: String? = nil) -> String {
        
        let baseFormat: String
        let defaults = UserDefaults.standard
        
        switch mediaType {
        case .movie:
            baseFormat = defaults.string(forKey: "movieFileFormat") ?? "{title} ({year}).mkv"
        case .tvShow:
            baseFormat = defaults.string(forKey: "tvShowFileFormat") ?? "{series} - S{season:02d}E{episode:02d} - {title}.mkv"
        case .unknown:
            baseFormat = "{title}.mkv"
        }
        
        var filename = baseFormat
            .replacingOccurrences(of: "{title}", with: metadata.title)
            .replacingOccurrences(of: "{series}", with: metadata.seriesName ?? metadata.title)
        
        // Handle year inclusion
        if defaults.bool(forKey: "includeYearInFilename") || baseFormat.contains("{year}") {
            filename = filename.replacingOccurrences(of: "{year}", with: String(metadata.year))
        } else {
            filename = filename.replacingOccurrences(of: " ({year})", with: "")
                .replacingOccurrences(of: "{year}", with: "")
        }
        
        // Handle season/episode formatting
        if let season = metadata.season, let episode = metadata.episode {
            let seasonEpisodeFormat = defaults.string(forKey: "seasonEpisodeFormat") ?? "S{season:02d}E{episode:02d}"
            let seasonEpisodeString = seasonEpisodeFormat
                .replacingOccurrences(of: "{season:02d}", with: String(format: "%02d", season))
                .replacingOccurrences(of: "{episode:02d}", with: String(format: "%02d", episode))
                .replacingOccurrences(of: "{season}", with: String(season))
                .replacingOccurrences(of: "{episode}", with: String(episode))
            
            filename = filename.replacingOccurrences(of: "S{season:02d}E{episode:02d}", with: seasonEpisodeString)
        }
        
        // Add resolution if enabled
        if defaults.bool(forKey: "includeResolutionInFilename"), let resolution = resolution {
            let nameWithoutExtension = (filename as NSString).deletingPathExtension
            let fileExtension = (filename as NSString).pathExtension
            filename = "\(nameWithoutExtension) [\(resolution)].\(fileExtension)"
        }
        
        // Add codec if enabled
        if defaults.bool(forKey: "includeCodecInFilename"), let codec = codec {
            let nameWithoutExtension = (filename as NSString).deletingPathExtension
            let fileExtension = (filename as NSString).pathExtension
            filename = "\(nameWithoutExtension) [\(codec)].\(fileExtension)"
        }
        
        return filename
    }
    
    // MARK: - Directory Creation Helper
    
    /// Creates directory structure if it doesn't exist
    /// - Parameter path: Directory path to create
    /// - Returns: Success status
    @discardableResult
    func createDirectoryIfNeeded(at path: String) -> Bool {
        let fileManager = FileManager.default
        
        if !fileManager.fileExists(atPath: path) {
            do {
                try fileManager.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
                return true
            } catch {
                print("Error creating directory at \(path): \(error)")
                return false
            }
        }
        
        return true
    }
    
    // MARK: - Post-Processing
    
    /// Executes post-processing script if configured
    /// - Parameters:
    ///   - outputPath: Path to the output file
    ///   - metadata: Media metadata
    func executePostProcessingScript(outputPath: String, metadata: MediaMetadata) {
        let scriptPath = UserDefaults.standard.string(forKey: "postProcessingScript")
        
        guard let scriptPath = scriptPath, !scriptPath.isEmpty,
              FileManager.default.fileExists(atPath: scriptPath) else {
            return
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: scriptPath)
        process.arguments = [outputPath, metadata.title, String(metadata.year)]
        
        do {
            try process.run()
            print("Post-processing script executed for: \(metadata.title)")
        } catch {
            print("Error executing post-processing script: \(error)")
        }
    }
}

// MARK: - Supporting Types

enum MediaType {
    case movie
    case tvShow
    case unknown
}

enum BonusContentType {
    case bonusFeatures
    case commentaries
    case deletedScenes
    case makingOf
    case trailers
}

struct MediaMetadata {
    let title: String
    let year: Int
    let seriesName: String?
    let season: Int?
    let episode: Int?
    let genre: String?
    
    init(title: String, year: Int, seriesName: String? = nil, season: Int? = nil, episode: Int? = nil, genre: String? = nil) {
        self.title = title
        self.year = year
        self.seriesName = seriesName
        self.season = season
        self.episode = episode
        self.genre = genre
    }
}
