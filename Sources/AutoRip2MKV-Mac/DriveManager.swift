import Foundation
import Cocoa

/// Protocol for drive detection functionality
/// Allows for dependency injection and better testability
protocol DriveDetecting {
    var delegate: DriveDetectorDelegate? { get set }
    func detectOpticalDrives() -> [OpticalDrive]
    func ejectDrive(_ drive: OpticalDrive) -> Bool
    func startMonitoring()
    func stopMonitoring()
}

/// Protocol for settings management
/// Allows for dependency injection and better testability
protocol SettingsManaging {
    var selectedDriveIndex: Int { get set }
}

/// Extend existing classes to conform to protocols
extension DriveDetector: DriveDetecting {
    func ejectDrive(_ drive: OpticalDrive) -> Bool {
        // Use diskutil to eject the drive
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/diskutil")
        task.arguments = ["eject", drive.devicePath]
        
        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            return false
        }
    }
}

extension SettingsManager: SettingsManaging {}

/// Protocol for managing optical drive detection, selection, and operations
/// This abstraction allows for dependency injection and better testability
protocol DriveManaging {
    /// Asynchronously detect all available optical drives
    func detectOpticalDrives() async -> [OpticalDrive]
    
    /// Select a specific drive for operations
    func selectDrive(_ drive: OpticalDrive)
    
    /// Eject the currently selected drive
    func ejectCurrentDrive() async throws
    
    /// Get the currently selected drive
    var selectedDrive: OpticalDrive? { get }
    
    /// Get all available drives  
    var availableDrives: [OpticalDrive] { get }
    
    /// Get the index of the selected drive in the available drives array
    var selectedDriveIndex: Int { get }
    
    /// Select a drive by index
    func selectDrive(at index: Int)
    
    /// Check if drives are currently being detected
    var isDetecting: Bool { get }
    
    /// Delegate for drive detection events
    var delegate: DriveDetectorDelegate? { get set }
    
    /// Generate a user-friendly display name for a drive
    func displayName(for drive: OpticalDrive) -> String
}

/// Manages optical drive detection, selection, and operations
/// Extracted from MainViewController to provide better separation of concerns
class DriveManager: DriveManaging, @unchecked Sendable {
    
    // MARK: - Properties
    
    private var driveDetector: DriveDetecting
    private var settingsManager: SettingsManaging
    private var cachedDrives: [OpticalDrive] = []
    private var selectedDriveInternal: OpticalDrive?
    private var isDetectingInternal = false
    
    // Cache management
    private var lastDetectionTime: Date = .distantPast
    private let cacheTimeout: TimeInterval = 30 // 30 seconds
    
    // MARK: - Initialization
    
    /// Initialize with dependency injection for better testability
    init(driveDetector: DriveDetecting = DriveDetector.shared,
         settingsManager: SettingsManaging = SettingsManager.shared) {
        self.driveDetector = driveDetector
        self.settingsManager = settingsManager
        
        // Set up drive detection monitoring
        setupDriveMonitoring()
    }
    
    // MARK: - Private Setup
    
    private func setupDriveMonitoring() {
        driveDetector.startMonitoring()
    }
    
    // MARK: - DriveManaging Implementation
    
    var selectedDrive: OpticalDrive? {
        return selectedDriveInternal
    }
    
    var availableDrives: [OpticalDrive] {
        return cachedDrives
    }
    
    var selectedDriveIndex: Int {
        guard let selected = selectedDriveInternal,
              let index = cachedDrives.firstIndex(where: { $0.devicePath == selected.devicePath }) else {
            return -1
        }
        return index
    }
    
    var isDetecting: Bool {
        return isDetectingInternal
    }
    
    var delegate: DriveDetectorDelegate? {
        get { return driveDetector.delegate }
        set { driveDetector.delegate = newValue }
    }
    
    func detectOpticalDrives() async -> [OpticalDrive] {
        // Use cached results if they're still fresh
        if shouldUseCachedResults() {
            return cachedDrives
        }
        
        isDetectingInternal = true
        defer { isDetectingInternal = false }
        
        // Perform detection on background queue
        let detectedDrives = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let drives = self.driveDetector.detectOpticalDrives()
                continuation.resume(returning: drives)
            }
        }
        
        // Update cache
        cachedDrives = detectedDrives
        lastDetectionTime = Date()
        
        // Restore previous selection if possible
        restorePreviousSelection()
        
        return detectedDrives
    }
    
    func selectDrive(_ drive: OpticalDrive) {
        selectedDriveInternal = drive
        
        // Save selection to settings
        if let index = cachedDrives.firstIndex(where: { $0.devicePath == drive.devicePath }) {
            settingsManager.selectedDriveIndex = index
        }
    }
    
    func selectDrive(at index: Int) {
        guard index >= 0 && index < cachedDrives.count else { return }
        selectDrive(cachedDrives[index])
    }
    
    func ejectCurrentDrive() async throws {
        guard let drive = selectedDriveInternal else {
            throw DriveManagerError.noDriveSelected
        }
        
        try await ejectDrive(drive)
    }
    
    // MARK: - Private Helper Methods
    
    private func shouldUseCachedResults() -> Bool {
        let timeSinceLastDetection = Date().timeIntervalSince(lastDetectionTime)
        return !cachedDrives.isEmpty && timeSinceLastDetection < cacheTimeout
    }
    
    private func restorePreviousSelection() {
        let savedIndex = settingsManager.selectedDriveIndex
        
        // Try to restore previous selection
        if savedIndex >= 0 && savedIndex < cachedDrives.count {
            selectedDriveInternal = cachedDrives[savedIndex]
        } else if cachedDrives.count == 1 {
            // Auto-select if only one drive
            selectedDriveInternal = cachedDrives[0]
            settingsManager.selectedDriveIndex = 0
        } else {
            selectedDriveInternal = nil
        }
    }
    
    private func ejectDrive(_ drive: OpticalDrive) async throws {
        // Use the drive detector's ejection method for better testability
        let success = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .background).async {
                let result = self.driveDetector.ejectDrive(drive)
                continuation.resume(returning: result)
            }
        }
        
        if success {
            // Clear selection since drive was ejected
            if selectedDriveInternal?.devicePath == drive.devicePath {
                selectedDriveInternal = nil
            }
        } else {
            throw DriveManagerError.ejectionFailed
        }
    }
    
    // MARK: - Cleanup
    
    deinit {
        driveDetector.stopMonitoring()
    }
}

// MARK: - Error Types

enum DriveManagerError: Error, LocalizedError {
    case noDriveSelected
    case ejectionFailed
    case ejectionTimeout
    case driveNotFound
    
    var errorDescription: String? {
        switch self {
        case .noDriveSelected:
            return "No drive selected for operation"
        case .ejectionFailed:
            return "Failed to eject drive"
        case .ejectionTimeout:
            return "Drive ejection timed out"
        case .driveNotFound:
            return "Selected drive not found"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .noDriveSelected:
            return "Please select an optical drive first"
        case .ejectionFailed:
            return "Try manually ejecting the disc or restart the application"
        case .ejectionTimeout:
            return "The drive may be busy. Wait a moment and try again"
        case .driveNotFound:
            return "Refresh the drive list and select a valid drive"
        }
    }
}

// MARK: - Extension for UI Helper Methods

extension DriveManager {
    
    /// Generate a user-friendly display name for a drive
    func displayName(for drive: OpticalDrive) -> String {
        let driveTypeString = drive.type == .dvd ? "DVD" :
                             drive.type == .bluray ? "Blu-ray" : "Unknown"
        return "\(drive.name) (\(driveTypeString))"
    }
    
    /// Get formatted drive information for logging
    func driveInfo(for drive: OpticalDrive) -> String {
        return "Drive: \(drive.displayName), Type: \(drive.type), Device: \(drive.devicePath), Mount: \(drive.mountPoint)"
    }
    
    /// Check if a drive is currently mounted and accessible
    func isDriveAccessible(_ drive: OpticalDrive) -> Bool {
        return FileManager.default.fileExists(atPath: drive.mountPoint)
    }
}