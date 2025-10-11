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
        print("[DriveDetector] Found \(mountedVolumes.count) mounted volumes")

        for volume in mountedVolumes {
            print("[DriveDetector] Checking volume: \(volume)")
            if isOpticalDrive(at: volume) {
                let driveInfo = getOpticalDriveInfo(at: volume)
                print("[DriveDetector] ✓ Movie disc detected: \(driveInfo.displayName) (\(driveInfo.type))")
                drives.append(driveInfo)
            } else {
                print("[DriveDetector] ✗ Not a movie disc: \(volume)")
            }
        }

        print("[DriveDetector] Total movie discs found: \(drives.count)")
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

    /// Checks if a volume is an optical drive with movie content
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

        // Check for DVD structure first (more specific)
        for indicator in dvdIndicators {
            let indicatorPath = (path as NSString).appendingPathComponent(indicator)
            if fileManager.fileExists(atPath: indicatorPath) {
                print("[DriveDetector]   Found DVD structure: \(indicator) at \(path)")
                return true
            }
        }

        // Check for Blu-ray structure
        for indicator in blurayIndicators {
            let indicatorPath = (path as NSString).appendingPathComponent(indicator)
            if fileManager.fileExists(atPath: indicatorPath) {
                print("[DriveDetector]   Found Blu-ray structure: \(indicator) at \(path)")
                return true
            }
        }

        // If no movie disc structure found, it's not a movie disc
        print("[DriveDetector]   No movie disc structure found at \(path)")
        return false
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
                let plist = try PropertyListSerialization.propertyList(
                    from: data, options: [], format: nil
                ) as? [String: Any]
                if let plist = plist,
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
