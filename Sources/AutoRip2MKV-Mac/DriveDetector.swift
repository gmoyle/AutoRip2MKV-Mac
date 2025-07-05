import Foundation
import IOKit

protocol DriveDetectorDelegate: AnyObject {
    func driveDetector(_ detector: DriveDetector, didDetectNewDisc drive: OpticalDrive)
    func driveDetector(_ detector: DriveDetector, didEjectDisc drive: OpticalDrive)
}

struct OpticalDrive {
    let mountPoint: String
    let name: String
    let type: MediaType
    let devicePath: String
    
    enum MediaType: Equatable {
        case dvd
        case bluray
        case unknown
    }
    
    var displayName: String {
        return "\(name) (\(mountPoint))"
    }
}

class DriveDetector {
    
    static let shared = DriveDetector()
    
    weak var delegate: DriveDetectorDelegate?
    private var isMonitoring = false
    private var monitoringTimer: Timer?
    private var lastKnownDrives: [OpticalDrive] = []
    
    private init() {}
    
    /// Detects all mounted optical drives
    func detectOpticalDrives() -> [OpticalDrive] {
        var drives: [OpticalDrive] = []
        
        // Get all mounted volumes
        let mountedVolumes = getMountedVolumes()
        
        for volume in mountedVolumes {
            if isOpticalDrive(at: volume) {
                let driveInfo = getOpticalDriveInfo(at: volume)
                drives.append(driveInfo)
            }
        }
        
        return drives
    }
    
    /// Gets all mounted volumes
    private func getMountedVolumes() -> [String] {
        var volumes: [String] = []
        
        let fileManager = FileManager.default
        let volumeKeys: [URLResourceKey] = [.volumeNameKey, .volumeIsRemovableKey]
        
        guard let mountedVolumeURLs = fileManager.mountedVolumeURLs(
            includingResourceValuesForKeys: volumeKeys, 
            options: []
        ) else {
            return volumes
        }
        
        for volumeURL in mountedVolumeURLs {
            do {
                let resourceValues = try volumeURL.resourceValues(forKeys: Set(volumeKeys))
                
                // Check if it's a removable volume (potential optical drive)
                if let isRemovable = resourceValues.volumeIsRemovable, isRemovable {
                    volumes.append(volumeURL.path)
                }
            } catch {
                continue
            }
        }
        
        return volumes
    }
    
    /// Checks if a volume is an optical drive
    private func isOpticalDrive(at path: String) -> Bool {
        // Check for common optical drive characteristics
        let fileManager = FileManager.default
        
        // Check for DVD/Blu-ray structure indicators
        let dvdIndicators = [
            "VIDEO_TS",
            "AUDIO_TS"
        ]
        
        let blurayIndicators = [
            "BDMV",
            "CERTIFICATE"
        ]
        
        // Check for DVD structure
        for indicator in dvdIndicators {
            let indicatorPath = (path as NSString).appendingPathComponent(indicator)
            if fileManager.fileExists(atPath: indicatorPath) {
                return true
            }
        }
        
        // Check for Blu-ray structure
        for indicator in blurayIndicators {
            let indicatorPath = (path as NSString).appendingPathComponent(indicator)
            if fileManager.fileExists(atPath: indicatorPath) {
                return true
            }
        }
        
        // Additional check: see if it's a disc by checking device properties
        return isRemovableMedia(at: path)
    }
    
    /// Gets optical drive information
    private func getOpticalDriveInfo(at path: String) -> OpticalDrive {
        _ = FileManager.default
        let url = URL(fileURLWithPath: path)
        
        // Determine media type
        let mediaType = determineMediaType(at: path)
        
        // Get volume name
        var volumeName = "Unknown Drive"
        do {
            let resourceValues = try url.resourceValues(forKeys: [.volumeNameKey])
            volumeName = resourceValues.volumeName ?? "Unknown Drive"
        } catch {
            // Fallback to last path component
            volumeName = url.lastPathComponent
        }
        
        // Get device path using diskutil
        let devicePath = getDevicePath(for: path) ?? "/dev/disk1"
        
        return OpticalDrive(mountPoint: path, name: volumeName, type: mediaType, devicePath: devicePath)
    }
    
    /// Determines the media type (DVD or Blu-ray)
    private func determineMediaType(at path: String) -> OpticalDrive.MediaType {
        let fileManager = FileManager.default
        
        // Check for Blu-ray indicators first
        let blurayIndicators = ["BDMV", "CERTIFICATE"]
        for indicator in blurayIndicators {
            let indicatorPath = (path as NSString).appendingPathComponent(indicator)
            if fileManager.fileExists(atPath: indicatorPath) {
                return .bluray
            }
        }
        
        // Check for DVD indicators
        let dvdIndicators = ["VIDEO_TS", "AUDIO_TS"]
        for indicator in dvdIndicators {
            let indicatorPath = (path as NSString).appendingPathComponent(indicator)
            if fileManager.fileExists(atPath: indicatorPath) {
                return .dvd
            }
        }
        
        return .unknown
    }
    
    /// Checks if the path represents removable media
    private func isRemovableMedia(at path: String) -> Bool {
        let url = URL(fileURLWithPath: path)
        
        do {
            let resourceValues = try url.resourceValues(forKeys: [.volumeIsRemovableKey])
            return resourceValues.volumeIsRemovable ?? false
        } catch {
            return false
        }
    }
    
    /// Gets the device path for a mount point using diskutil
    private func getDevicePath(for mountPoint: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        process.arguments = ["info", "-plist", mountPoint]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
                   let deviceIdentifier = plist["DeviceIdentifier"] as? String {
                    return "/dev/\(deviceIdentifier)"
                }
            }
        } catch {
            print("Error getting device path: \(error)")
        }
        
        return nil
    }
    
    // MARK: - Automatic Monitoring
    
    /// Starts monitoring for disc insertion/ejection
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        lastKnownDrives = detectOpticalDrives()
        
        // Start polling for changes every 2 seconds
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkForDriveChanges()
        }
    }
    
    /// Stops monitoring for disc changes
    func stopMonitoring() {
        isMonitoring = false
        monitoringTimer?.invalidate()
        monitoringTimer = nil
    }
    
    /// Checks for changes in optical drives
    private func checkForDriveChanges() {
        let currentDrives = detectOpticalDrives()
        
        // Check for newly inserted discs
        for drive in currentDrives {
            if !lastKnownDrives.contains(where: { $0.mountPoint == drive.mountPoint }) {
                delegate?.driveDetector(self, didDetectNewDisc: drive)
            }
        }
        
        // Check for ejected discs
        for drive in lastKnownDrives {
            if !currentDrives.contains(where: { $0.mountPoint == drive.mountPoint }) {
                delegate?.driveDetector(self, didEjectDisc: drive)
            }
        }
        
        lastKnownDrives = currentDrives
    }
}

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
