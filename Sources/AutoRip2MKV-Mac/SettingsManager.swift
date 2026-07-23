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
        static let autoQueueEnabled = "autoQueueEnabled"
        static let autoQueuePriorityByMediaType = "autoQueuePriorityByMediaType"
        static let videoCodec = "videoCodec"
        static let audioCodec = "audioCodec"
        static let quality = "quality"
        static let includeSubtitles = "includeSubtitles"
        static let includeChapters = "includeChapters"
        static let hardwareAcceleration = "hardwareAcceleration"
        static let hardwareAccelerationChecked = "hardwareAccelerationChecked"
        static let autoDeinterlace = "autoDeinterlace"
        
        // Intelligent Title Selection (Phase 2 Task 3)
        static let intelligentTitleSelection = "intelligentTitleSelection"
        static let skipMenus = "skipMenus"
        static let skipTrailers = "skipTrailers"
        static let skipDuplicates = "skipDuplicates"
        static let autoSelectMainFeature = "autoSelectMainFeature"
        static let preferLongestTitle = "preferLongestTitle"
        static let minMainFeatureDuration = "minMainFeatureDuration"
        static let minBonusFeatureDuration = "minBonusFeatureDuration"

        static let preProcessingScript = "preProcessingScript"
        static let postProcessingScript = "postProcessingScript"
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
    
    var autoQueueEnabled: Bool {
        get {
            return userDefaults.bool(forKey: Keys.autoQueueEnabled)
        }
        set {
            userDefaults.set(newValue, forKey: Keys.autoQueueEnabled)
        }
    }
    
    var autoQueuePriorityByMediaType: Bool {
        get {
            return userDefaults.bool(forKey: Keys.autoQueuePriorityByMediaType)
        }
        set {
            userDefaults.set(newValue, forKey: Keys.autoQueuePriorityByMediaType)
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

    /// Deinterlace frames flagged as interlaced (common on NTSC DVDs) during encode
    var autoDeinterlace: Bool {
        get {
            return userDefaults.bool(forKey: Keys.autoDeinterlace)
        }
        set {
            userDefaults.set(newValue, forKey: Keys.autoDeinterlace)
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

    // MARK: - Script Hook Settings

    var preProcessingScript: String? {
        get {
            return userDefaults.string(forKey: Keys.preProcessingScript)
        }
        set {
            userDefaults.set(newValue, forKey: Keys.preProcessingScript)
        }
    }

    var postProcessingScript: String? {
        get {
            return userDefaults.string(forKey: Keys.postProcessingScript)
        }
        set {
            userDefaults.set(newValue, forKey: Keys.postProcessingScript)
        }
    }
    
    // MARK: - Intelligent Title Selection Settings (Phase 2 Task 3)
    
    var intelligentTitleSelection: Bool {
        get {
            return userDefaults.bool(forKey: Keys.intelligentTitleSelection)
        }
        set {
            userDefaults.set(newValue, forKey: Keys.intelligentTitleSelection)
        }
    }
    
    var skipMenus: Bool {
        get {
            return userDefaults.bool(forKey: Keys.skipMenus)
        }
        set {
            userDefaults.set(newValue, forKey: Keys.skipMenus)
        }
    }
    
    var skipTrailers: Bool {
        get {
            return userDefaults.bool(forKey: Keys.skipTrailers)
        }
        set {
            userDefaults.set(newValue, forKey: Keys.skipTrailers)
        }
    }
    
    var skipDuplicates: Bool {
        get {
            return userDefaults.bool(forKey: Keys.skipDuplicates)
        }
        set {
            userDefaults.set(newValue, forKey: Keys.skipDuplicates)
        }
    }
    
    var autoSelectMainFeature: Bool {
        get {
            return userDefaults.bool(forKey: Keys.autoSelectMainFeature)
        }
        set {
            userDefaults.set(newValue, forKey: Keys.autoSelectMainFeature)
        }
    }
    
    var preferLongestTitle: Bool {
        get {
            return userDefaults.bool(forKey: Keys.preferLongestTitle)
        }
        set {
            userDefaults.set(newValue, forKey: Keys.preferLongestTitle)
        }
    }
    
    var minMainFeatureDuration: TimeInterval {
        get {
            let value = userDefaults.double(forKey: Keys.minMainFeatureDuration)
            return value > 0 ? value : 3600 // Default 60 minutes
        }
        set {
            userDefaults.set(newValue, forKey: Keys.minMainFeatureDuration)
        }
    }
    
    var minBonusFeatureDuration: TimeInterval {
        get {
            let value = userDefaults.double(forKey: Keys.minBonusFeatureDuration)
            return value > 0 ? value : 300 // Default 5 minutes
        }
        set {
            userDefaults.set(newValue, forKey: Keys.minBonusFeatureDuration)
        }
    }
    
    /// Get TitleAnalyzer.FilteringRules from current settings
    func getTitleFilteringRules() -> TitleAnalyzer.FilteringRules {
        var rules = TitleAnalyzer.FilteringRules()
        
        if intelligentTitleSelection {
            rules.skipMenus = skipMenus
            rules.skipTrailers = skipTrailers
            rules.skipDuplicates = skipDuplicates
            rules.autoSelectMainFeature = autoSelectMainFeature
            rules.preferLongestTitle = preferLongestTitle
            rules.minMainFeatureDuration = minMainFeatureDuration
            rules.minBonusFeatureDuration = minBonusFeatureDuration
        } else {
            // Intelligent filtering disabled - only apply basic duration filter
            rules.skipMenus = false
            rules.skipTrailers = false
            rules.skipDuplicates = false
            rules.autoSelectMainFeature = false
        }
        
        return rules
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
        if userDefaults.object(forKey: Keys.autoQueueEnabled) == nil {
            autoQueueEnabled = true  // Auto-queue enabled by default
        }
        if userDefaults.object(forKey: Keys.autoQueuePriorityByMediaType) == nil {
            autoQueuePriorityByMediaType = true  // Use media-type priority by default
        }
        if userDefaults.object(forKey: Keys.autoDeinterlace) == nil {
            autoDeinterlace = true  // Deinterlace flagged frames by default
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
        
        // Intelligent Title Selection defaults (Phase 2 Task 3)
        if userDefaults.object(forKey: Keys.intelligentTitleSelection) == nil {
            intelligentTitleSelection = true  // Enabled by default
        }
        if userDefaults.object(forKey: Keys.skipMenus) == nil {
            skipMenus = true  // Skip menus by default
        }
        if userDefaults.object(forKey: Keys.skipTrailers) == nil {
            skipTrailers = true  // Skip trailers by default
        }
        if userDefaults.object(forKey: Keys.skipDuplicates) == nil {
            skipDuplicates = true  // Skip duplicates by default
        }
        if userDefaults.object(forKey: Keys.autoSelectMainFeature) == nil {
            autoSelectMainFeature = false  // Don't auto-select by default (let user choose)
        }
        if userDefaults.object(forKey: Keys.preferLongestTitle) == nil {
            preferLongestTitle = true  // Prefer longest when multiple main features
        }
        if userDefaults.object(forKey: Keys.minMainFeatureDuration) == nil {
            minMainFeatureDuration = 3600  // 60 minutes
        }
        if userDefaults.object(forKey: Keys.minBonusFeatureDuration) == nil {
            minBonusFeatureDuration = 300  // 5 minutes
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
        setDefaultIfNeeded("preProcessingScript", value: "")
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
