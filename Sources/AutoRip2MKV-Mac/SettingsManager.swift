import Foundation

// MARK: - Settings Manager

class SettingsManager {

    static let shared = SettingsManager()

    private let userDefaults = UserDefaults.standard

    private enum Keys {
        static let lastSourcePath = "lastSourcePath"
        static let lastOutputPath = "lastOutputPath"
        static let selectedDriveIndex = "selectedDriveIndex"
        static let autoRipEnabled = "autoRipEnabled"
        static let autoEjectEnabled = "autoEjectEnabled"
        static let videoCodec = "videoCodec"
        static let audioCodec = "audioCodec"
        static let quality = "quality"
        static let includeSubtitles = "includeSubtitles"
        static let includeChapters = "includeChapters"
        static let hardwareAcceleration = "hardwareAcceleration"
        static let hardwareAccelerationChecked = "hardwareAccelerationChecked"
    }

    private init() {}

    // MARK: - Source Path

    var lastSourcePath: String? {
        get {
            return userDefaults.string(forKey: Keys.lastSourcePath)
        }
        set {
            userDefaults.set(newValue, forKey: Keys.lastSourcePath)
        }
    }

    // MARK: - Output Path

    var lastOutputPath: String? {
        get {
            return userDefaults.string(forKey: Keys.lastOutputPath)
        }
        set {
            userDefaults.set(newValue, forKey: Keys.lastOutputPath)
        }
    }

    // MARK: - Selected Drive

    var selectedDriveIndex: Int {
        get {
            return userDefaults.integer(forKey: Keys.selectedDriveIndex)
        }
        set {
            userDefaults.set(newValue, forKey: Keys.selectedDriveIndex)
        }
    }

    // MARK: - Automation Settings

    var autoRipEnabled: Bool {
        get {
            return userDefaults.bool(forKey: Keys.autoRipEnabled)
        }
        set {
            userDefaults.set(newValue, forKey: Keys.autoRipEnabled)
        }
    }

    var autoEjectEnabled: Bool {
        get {
            return userDefaults.bool(forKey: Keys.autoEjectEnabled)
        }
        set {
            userDefaults.set(newValue, forKey: Keys.autoEjectEnabled)
        }
    }

    // MARK: - Ripping Settings

    var videoCodec: String {
        get {
            return userDefaults.string(forKey: Keys.videoCodec) ?? "h264"
        }
        set {
            userDefaults.set(newValue, forKey: Keys.videoCodec)
        }
    }

    var audioCodec: String {
        get {
            return userDefaults.string(forKey: Keys.audioCodec) ?? "aac"
        }
        set {
            userDefaults.set(newValue, forKey: Keys.audioCodec)
        }
    }

    var quality: String {
        get {
            return userDefaults.string(forKey: Keys.quality) ?? "high"
        }
        set {
            userDefaults.set(newValue, forKey: Keys.quality)
        }
    }

    var includeSubtitles: Bool {
        get {
            return userDefaults.bool(forKey: Keys.includeSubtitles)
        }
        set {
            userDefaults.set(newValue, forKey: Keys.includeSubtitles)
        }
    }

    var includeChapters: Bool {
        get {
            return userDefaults.bool(forKey: Keys.includeChapters)
        }
        set {
            userDefaults.set(newValue, forKey: Keys.includeChapters)
        }
    }
    
    // MARK: - Hardware Acceleration Settings
    
    var hardwareAcceleration: Bool {
        get {
            return userDefaults.bool(forKey: Keys.hardwareAcceleration)
        }
        set {
            userDefaults.set(newValue, forKey: Keys.hardwareAcceleration)
        }
    }
    
    var hardwareAccelerationChecked: Bool {
        get {
            return userDefaults.bool(forKey: Keys.hardwareAccelerationChecked)
        }
        set {
            userDefaults.set(newValue, forKey: Keys.hardwareAccelerationChecked)
        }
    }

    // MARK: - Convenience Methods

    func saveSettings(sourcePath: String?, outputPath: String?, driveIndex: Int) {
        lastSourcePath = sourcePath
        lastOutputPath = outputPath
        selectedDriveIndex = driveIndex
        userDefaults.synchronize()
    }

    func setDefaultsIfNeeded() {
        if userDefaults.object(forKey: Keys.autoRipEnabled) == nil {
            autoRipEnabled = true
        }
        if userDefaults.object(forKey: Keys.autoEjectEnabled) == nil {
            autoEjectEnabled = true
        }
        if userDefaults.object(forKey: Keys.includeSubtitles) == nil {
            includeSubtitles = true
        }
        if userDefaults.object(forKey: Keys.includeChapters) == nil {
            includeChapters = true
        }
        if userDefaults.object(forKey: Keys.hardwareAcceleration) == nil {
            hardwareAcceleration = false // Disabled by default
        }

        // Set extended defaults
        setExtendedDefaultsIfNeeded()

        userDefaults.synchronize()
    }

    // MARK: - Extended Settings with Defaults

    private func setExtendedDefaultsIfNeeded() {
        setFileStorageDefaults()
        setBonusContentDefaults()
        setFileNamingDefaults()
        setAdvancedDefaults()
    }

    private func setFileStorageDefaults() {
        setDefaultIfNeeded("outputStructureType", value: 1) // By Media Type
        setDefaultIfNeeded("createSeriesDirectory", value: true)
        setDefaultIfNeeded("createSeasonDirectory", value: true)
        setDefaultIfNeeded("movieDirectoryFormat", value: "Movies/{title} ({year})")
        setDefaultIfNeeded("tvShowDirectoryFormat", value: "TV Shows/{series}/Season {season}")
    }

    private func setBonusContentDefaults() {
        setDefaultIfNeeded("includeBonusFeatures", value: false)
        setDefaultIfNeeded("includeCommentaries", value: false)
        setDefaultIfNeeded("includeDeletedScenes", value: false)
        setDefaultIfNeeded("includeMakingOf", value: false)
        setDefaultIfNeeded("includeTrailers", value: false)
        setDefaultIfNeeded("bonusContentStructure", value: 1) // Separate 'Bonus' subdirectory
        setDefaultIfNeeded("bonusContentDirectory", value: "Bonus")
    }

    private func setFileNamingDefaults() {
        setDefaultIfNeeded("movieFileFormat", value: "{title} ({year}).mkv")
        setDefaultIfNeeded("tvShowFileFormat", value: "{series} - S{season:02d}E{episode:02d} - {title}.mkv")
        setDefaultIfNeeded("seasonEpisodeFormat", value: "S{season:02d}E{episode:02d}")
        setDefaultIfNeeded("includeYearInFilename", value: true)
        setDefaultIfNeeded("includeResolutionInFilename", value: false)
        setDefaultIfNeeded("includeCodecInFilename", value: false)
    }

    private func setAdvancedDefaults() {
        setDefaultIfNeeded("preserveOriginalTimestamps", value: false)
        setDefaultIfNeeded("createBackups", value: false)
        setDefaultIfNeeded("autoRetryOnFailure", value: true)
        setDefaultIfNeeded("maxRetryAttempts", value: 3)
        setDefaultIfNeeded("postProcessingScript", value: "")
    }

    private func setDefaultIfNeeded<T>(_ key: String, value: T) {
        if userDefaults.object(forKey: key) == nil {
            userDefaults.set(value, forKey: key)
        }
    }

    // MARK: - Extended Settings Getters

    var outputStructureType: Int {
        return userDefaults.integer(forKey: "outputStructureType")
    }

    var createSeriesDirectory: Bool {
        return userDefaults.bool(forKey: "createSeriesDirectory")
    }

    var createSeasonDirectory: Bool {
        return userDefaults.bool(forKey: "createSeasonDirectory")
    }

    var movieDirectoryFormat: String {
        return userDefaults.string(forKey: "movieDirectoryFormat") ?? "Movies/{title} ({year})"
    }

    var tvShowDirectoryFormat: String {
        return userDefaults.string(forKey: "tvShowDirectoryFormat") ?? "TV Shows/{series}/Season {season}"
    }

    var includeBonusFeatures: Bool {
        return userDefaults.bool(forKey: "includeBonusFeatures")
    }

    var includeCommentaries: Bool {
        return userDefaults.bool(forKey: "includeCommentaries")
    }

    var includeDeletedScenes: Bool {
        return userDefaults.bool(forKey: "includeDeletedScenes")
    }

    var includeMakingOf: Bool {
        return userDefaults.bool(forKey: "includeMakingOf")
    }

    var includeTrailers: Bool {
        return userDefaults.bool(forKey: "includeTrailers")
    }

    var bonusContentStructure: Int {
        return userDefaults.integer(forKey: "bonusContentStructure")
    }

    var bonusContentDirectory: String {
        return userDefaults.string(forKey: "bonusContentDirectory") ?? "Bonus"
    }
}
