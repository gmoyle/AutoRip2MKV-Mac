import Foundation
import IOKit

struct OpticalDrive {
    let mountPoint: String
    let name: String
    let type: MediaType
    
    enum MediaType {
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
        
        return OpticalDrive(mountPoint: path, name: volumeName, type: mediaType)
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
}

// MARK: - Settings Manager

class SettingsManager {
    
    static let shared = SettingsManager()
    
    private let userDefaults = UserDefaults.standard
    
    private enum Keys {
        static let lastSourcePath = "lastSourcePath"
        static let lastOutputPath = "lastOutputPath"
        static let selectedDriveIndex = "selectedDriveIndex"
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
    
    // MARK: - Convenience Methods
    
    func saveSettings(sourcePath: String?, outputPath: String?, driveIndex: Int) {
        lastSourcePath = sourcePath
        lastOutputPath = outputPath
        selectedDriveIndex = driveIndex
        userDefaults.synchronize()
    }
}
