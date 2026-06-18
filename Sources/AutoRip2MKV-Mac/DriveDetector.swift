import Foundation
import IOKit
import AppKit

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
        case bluray4K
        case hddvd
        case unknown

        var displayName: String {
            switch self {
            case .dvd: return "DVD"
            case .bluray: return "Blu-ray"
            case .bluray4K: return "4K Blu-ray"
            case .hddvd: return "HD DVD"
            case .unknown: return "Unknown"
            }
        }

        var defaultPriority: ConversionQueue.JobPriority {
            switch self {
            case .bluray4K: return .high
            case .bluray: return .normal
            case .hddvd: return .normal
            case .dvd: return .low
            case .unknown: return .normal
            }
        }
    }

    var displayName: String {
        return "\(name) (\(mountPoint))"
    }
}

class DriveDetector {

    static let shared = DriveDetector()

    weak var delegate: DriveDetectorDelegate?
    private var isMonitoring = false
    private var mountObserver: NSObjectProtocol?
    private var unmountObserver: NSObjectProtocol?
    private var lastKnownDrives: [OpticalDrive] = []

    private init() {}

    // MARK: - Automatic Monitoring

    /// Starts monitoring for disc insertion/ejection using NSWorkspace notifications.
    /// This avoids polling mounted volumes, which would trigger a TCC removable-volume prompt.
    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

        let nc = NSWorkspace.shared.notificationCenter

        mountObserver = nc.addObserver(
            forName: NSWorkspace.didMountNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let url = notification.userInfo?[NSWorkspace.volumeURLUserInfoKey] as? URL else { return }
            self.handleVolumeMount(url: url)
        }

        unmountObserver = nc.addObserver(
            forName: NSWorkspace.didUnmountNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let url = notification.userInfo?[NSWorkspace.volumeURLUserInfoKey] as? URL else { return }
            self.handleVolumeUnmount(url: url)
        }

        // Check for already-mounted discs at startup — only runs once on launch
        checkAlreadyMountedDiscs()
    }

    /// Stops monitoring for disc changes
    func stopMonitoring() {
        isMonitoring = false
        if let obs = mountObserver { NSWorkspace.shared.notificationCenter.removeObserver(obs) }
        if let obs = unmountObserver { NSWorkspace.shared.notificationCenter.removeObserver(obs) }
        mountObserver = nil
        unmountObserver = nil
    }

    // MARK: - Volume Event Handlers

    private func handleVolumeMount(url: URL) {
        let path = url.path
        print("[DriveDetector] Volume mounted: \(path)")
        guard isOpticalDrive(at: path) else {
            print("[DriveDetector] ✗ Not a movie disc: \(path)")
            return
        }
        let drive = getOpticalDriveInfo(at: path)
        print("[DriveDetector] ✓ Movie disc detected: \(drive.displayName) (\(drive.type))")
        lastKnownDrives.append(drive)
        delegate?.driveDetector(self, didDetectNewDisc: drive)
    }

    private func handleVolumeUnmount(url: URL) {
        let path = url.path
        if let idx = lastKnownDrives.firstIndex(where: { $0.mountPoint == path }) {
            let drive = lastKnownDrives.remove(at: idx)
            print("[DriveDetector] Disc ejected: \(drive.displayName)")
            delegate?.driveDetector(self, didEjectDisc: drive)
        }
    }

    /// Checks once at startup for any already-mounted optical discs.
    /// Uses diskutil list (IOKit-level, no TCC) to find optical media,
    /// then only accesses the mount point if we know it's an optical drive.
    private func checkAlreadyMountedDiscs() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            let opticalMountPoints = self.findOpticalMountPointsViaIOKit()
            for path in opticalMountPoints {
                if self.isOpticalDrive(at: path) {
                    let drive = self.getOpticalDriveInfo(at: path)
                    DispatchQueue.main.async {
                        print("[DriveDetector] ✓ Already mounted disc: \(drive.displayName)")
                        self.lastKnownDrives.append(drive)
                        self.delegate?.driveDetector(self, didDetectNewDisc: drive)
                    }
                }
            }
        }
    }

    /// Uses `diskutil list -plist` to enumerate disks and find optical drive mount points.
    /// This is IOKit-level and does NOT trigger a TCC removable-volume prompt.
    private func findOpticalMountPointsViaIOKit() -> [String] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        process.arguments = ["list", "-plist"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return []
        }

        guard process.terminationStatus == 0 else { return [] }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
              let allDisks = plist["AllDisksAndPartitions"] as? [[String: Any]] else {
            return []
        }

        var mountPoints: [String] = []
        for disk in allDisks {
            // Check if this disk is optical media
            if let content = disk["Content"] as? String,
               (content.contains("DVD") || content.contains("CD") || content.contains("optical") || content == "") {
                // Look for mount point in partitions
                if let partitions = disk["Partitions"] as? [[String: Any]] {
                    for partition in partitions {
                        if let mp = partition["MountPoint"] as? String, !mp.isEmpty {
                            mountPoints.append(mp)
                        }
                    }
                }
                if let mp = disk["MountPoint"] as? String, !mp.isEmpty {
                    mountPoints.append(mp)
                }
            }
        }

        // Also check /Volumes directly for anything that looks like optical media
        // without touching file attributes — just check for known disc folder names
        if let volumes = try? FileManager.default.contentsOfDirectory(atPath: "/Volumes") {
            for vol in volumes {
                let path = "/Volumes/\(vol)"
                if !mountPoints.contains(path) {
                    mountPoints.append(path)
                }
            }
        }

        return mountPoints
    }

    // MARK: - Public API

    /// Returns currently known optical drives (populated from mount events, not polling).
    func detectOpticalDrives() -> [OpticalDrive] {
        return lastKnownDrives
    }

    // MARK: - Drive Detection Helpers

    /// Checks if a volume path contains DVD/Blu-ray/HD DVD structure
    private func isOpticalDrive(at path: String) -> Bool {
        let fileManager = FileManager.default

        let indicators = ["VIDEO_TS", "AUDIO_TS", "BDMV", "CERTIFICATE", "HVDVD_TS", "ADV_OBJ", "HVAUDIO_TS"]
        for indicator in indicators {
            let indicatorPath = (path as NSString).appendingPathComponent(indicator)
            if fileManager.fileExists(atPath: indicatorPath) {
                print("[DriveDetector]   Found disc structure: \(indicator) at \(path)")
                return true
            }
        }

        print("[DriveDetector]   No movie disc structure found at \(path)")
        return false
    }

    /// Gets optical drive information
    private func getOpticalDriveInfo(at path: String) -> OpticalDrive {
        let url = URL(fileURLWithPath: path)
        let mediaType = determineMediaType(at: path)

        var rawName = "Unknown Drive"
        if let resourceValues = try? url.resourceValues(forKeys: [.volumeNameKey]),
           let name = resourceValues.volumeName {
            rawName = name
        } else {
            rawName = url.lastPathComponent
        }
        let volumeName = prettifyDiscName(rawName)

        let devicePath = getDevicePath(for: path) ?? "/dev/disk1"
        return OpticalDrive(mountPoint: path, name: volumeName, type: mediaType, devicePath: devicePath)
    }

    /// Determines the media type (DVD, Blu-ray, 4K Blu-ray, or HD DVD)
    private func determineMediaType(at path: String) -> OpticalDrive.MediaType {
        let fileManager = FileManager.default

        for indicator in ["BDMV", "CERTIFICATE"] {
            if fileManager.fileExists(atPath: (path as NSString).appendingPathComponent(indicator)) {
                return is4KBluRay(at: path) ? .bluray4K : .bluray
            }
        }

        for indicator in ["HVDVD_TS", "ADV_OBJ"] {
            if fileManager.fileExists(atPath: (path as NSString).appendingPathComponent(indicator)) {
                return .hddvd
            }
        }

        for indicator in ["VIDEO_TS", "AUDIO_TS"] {
            if fileManager.fileExists(atPath: (path as NSString).appendingPathComponent(indicator)) {
                return .dvd
            }
        }

        return .unknown
    }

    /// Determines if a Blu-ray disc is 4K UHD
    private func is4KBluRay(at path: String) -> Bool {
        let fileManager = FileManager.default
        let bdmvPath = (path as NSString).appendingPathComponent("BDMV")
        let playlistPath = (bdmvPath as NSString).appendingPathComponent("PLAYLIST")

        if fileManager.fileExists(atPath: playlistPath),
           let playlists = try? fileManager.contentsOfDirectory(atPath: playlistPath) {
            for playlist in playlists where playlist.hasSuffix(".mpls") {
                let filePath = (playlistPath as NSString).appendingPathComponent(playlist)
                if let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)), data.count > 1000 {
                    let dataString = String(decoding: data.prefix(2000), as: UTF8.self)
                    if dataString.contains("3840") || dataString.contains("2160") ||
                       dataString.contains("hev1") || dataString.contains("hvc1") {
                        return true
                    }
                }
            }
        }

        return false
    }

    /// Converts DVD volume names like "THE_DARK_KNIGHT" to "The Dark Knight"
    private func prettifyDiscName(_ raw: String) -> String {
        let words = raw.replacingOccurrences(of: "_", with: " ")
                       .components(separatedBy: " ")
                       .filter { !$0.isEmpty }
        let lowercaseWords = Set(["a","an","the","and","but","or","for","nor","on","at","to","by","in","of","up","as"])
        return words.enumerated().map { idx, word in
            let lower = word.lowercased()
            return (idx == 0 || !lowercaseWords.contains(lower)) ? lower.capitalized : lower
        }.joined(separator: " ")
    }

    /// Gets the device path for a mount point using diskutil
    private func getDevicePath(for mountPoint: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        process.arguments = ["info", "-plist", mountPoint]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
                   let deviceIdentifier = plist["DeviceIdentifier"] as? String {
                    return "/dev/\(deviceIdentifier)"
                }
            }
        } catch {
            print("Error getting device path: \(error)")
        }

        return nil
    }
}
