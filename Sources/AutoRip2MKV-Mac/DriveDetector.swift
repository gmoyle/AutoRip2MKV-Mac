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
        // File Storage defaults
        if userDefaults.object(forKey: "outputStructureType") == nil {
            userDefaults.set(1, forKey: "outputStructureType") // By Media Type
        }
        if userDefaults.object(forKey: "createSeriesDirectory") == nil {
            userDefaults.set(true, forKey: "createSeriesDirectory")
        }
        if userDefaults.object(forKey: "createSeasonDirectory") == nil {
            userDefaults.set(true, forKey: "createSeasonDirectory")
        }
        if userDefaults.object(forKey: "movieDirectoryFormat") == nil {
            userDefaults.set("Movies/{title} ({year})", forKey: "movieDirectoryFormat")
        }
        if userDefaults.object(forKey: "tvShowDirectoryFormat") == nil {
            userDefaults.set("TV Shows/{series}/Season {season}", forKey: "tvShowDirectoryFormat")
        }
        
        // Bonus Content defaults
        if userDefaults.object(forKey: "includeBonusFeatures") == nil {
            userDefaults.set(false, forKey: "includeBonusFeatures")
        }
        if userDefaults.object(forKey: "includeCommentaries") == nil {
            userDefaults.set(false, forKey: "includeCommentaries")
        }
        if userDefaults.object(forKey: "includeDeletedScenes") == nil {
            userDefaults.set(false, forKey: "includeDeletedScenes")
        }
        if userDefaults.object(forKey: "includeMakingOf") == nil {
            userDefaults.set(false, forKey: "includeMakingOf")
        }
        if userDefaults.object(forKey: "includeTrailers") == nil {
            userDefaults.set(false, forKey: "includeTrailers")
        }
        if userDefaults.object(forKey: "bonusContentStructure") == nil {
            userDefaults.set(1, forKey: "bonusContentStructure") // Separate 'Bonus' subdirectory
        }
        if userDefaults.object(forKey: "bonusContentDirectory") == nil {
            userDefaults.set("Bonus", forKey: "bonusContentDirectory")
        }
        
        // File Naming defaults
        if userDefaults.object(forKey: "movieFileFormat") == nil {
            userDefaults.set("{title} ({year}).mkv", forKey: "movieFileFormat")
        }
        if userDefaults.object(forKey: "tvShowFileFormat") == nil {
            userDefaults.set("{series} - S{season:02d}E{episode:02d} - {title}.mkv", forKey: "tvShowFileFormat")
        }
        if userDefaults.object(forKey: "seasonEpisodeFormat") == nil {
            userDefaults.set("S{season:02d}E{episode:02d}", forKey: "seasonEpisodeFormat")
        }
        if userDefaults.object(forKey: "includeYearInFilename") == nil {
            userDefaults.set(true, forKey: "includeYearInFilename")
        }
        if userDefaults.object(forKey: "includeResolutionInFilename") == nil {
            userDefaults.set(false, forKey: "includeResolutionInFilename")
        }
        if userDefaults.object(forKey: "includeCodecInFilename") == nil {
            userDefaults.set(false, forKey: "includeCodecInFilename")
        }
        
        // Advanced defaults
        if userDefaults.object(forKey: "preserveOriginalTimestamps") == nil {
            userDefaults.set(false, forKey: "preserveOriginalTimestamps")
        }
        if userDefaults.object(forKey: "createBackups") == nil {
            userDefaults.set(false, forKey: "createBackups")
        }
        if userDefaults.object(forKey: "autoRetryOnFailure") == nil {
            userDefaults.set(true, forKey: "autoRetryOnFailure")
        }
        if userDefaults.object(forKey: "maxRetryAttempts") == nil {
            userDefaults.set(3, forKey: "maxRetryAttempts")
        }
        if userDefaults.object(forKey: "postProcessingScript") == nil {
            userDefaults.set("", forKey: "postProcessingScript")
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
