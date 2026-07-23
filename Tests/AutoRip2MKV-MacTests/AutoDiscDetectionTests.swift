//
//  AutoDiscDetectionTests.swift
//  AutoRip2MKV-MacTests
//
//  Tests for Phase 2 auto-disc detection enhancements
//

import XCTest
@testable import AutoRip2MKV_Mac

final class AutoDiscDetectionTests: XCTestCase {
    
    // MARK: - Media Type Tests
    
    func testMediaTypeDisplayNames() {
        XCTAssertEqual(OpticalDrive.MediaType.dvd.displayName, "DVD")
        XCTAssertEqual(OpticalDrive.MediaType.bluray.displayName, "Blu-ray")
        XCTAssertEqual(OpticalDrive.MediaType.bluray4K.displayName, "4K Blu-ray")
        XCTAssertEqual(OpticalDrive.MediaType.hddvd.displayName, "HD DVD")
        XCTAssertEqual(OpticalDrive.MediaType.unknown.displayName, "Unknown")
    }
    
    func testMediaTypeDefaultPriorities() {
        XCTAssertEqual(OpticalDrive.MediaType.bluray4K.defaultPriority, .high)
        XCTAssertEqual(OpticalDrive.MediaType.bluray.defaultPriority, .normal)
        XCTAssertEqual(OpticalDrive.MediaType.hddvd.defaultPriority, .normal)
        XCTAssertEqual(OpticalDrive.MediaType.dvd.defaultPriority, .low)
        XCTAssertEqual(OpticalDrive.MediaType.unknown.defaultPriority, .normal)
    }
    
    func testMediaTypePriorityOrdering() {
        // 4K Blu-ray should have highest priority
        XCTAssertTrue(OpticalDrive.MediaType.bluray4K.defaultPriority > OpticalDrive.MediaType.bluray.defaultPriority)
        XCTAssertTrue(OpticalDrive.MediaType.bluray4K.defaultPriority > OpticalDrive.MediaType.hddvd.defaultPriority)
        XCTAssertTrue(OpticalDrive.MediaType.bluray4K.defaultPriority > OpticalDrive.MediaType.dvd.defaultPriority)
        
        // DVD should have lowest priority (excluding unknown)
        XCTAssertTrue(OpticalDrive.MediaType.dvd.defaultPriority < OpticalDrive.MediaType.bluray.defaultPriority)
        XCTAssertTrue(OpticalDrive.MediaType.dvd.defaultPriority < OpticalDrive.MediaType.hddvd.defaultPriority)
        
        // Blu-ray and HD DVD should have same priority
        XCTAssertEqual(OpticalDrive.MediaType.bluray.defaultPriority, OpticalDrive.MediaType.hddvd.defaultPriority)
    }
    
    // MARK: - Settings Tests
    
    func testAutoQueueEnabledDefault() {
        let settings = SettingsManager.shared
        
        // Clear existing value to test default behavior
        UserDefaults.standard.removeObject(forKey: "autoQueueEnabled")
        
        settings.setDefaultsIfNeeded()
        
        // Auto-queue should be enabled by default
        XCTAssertTrue(settings.autoQueueEnabled)
    }
    
    func testAutoQueuePriorityByMediaTypeDefault() {
        let settings = SettingsManager.shared
        
        // Clear existing value to test default behavior
        UserDefaults.standard.removeObject(forKey: "autoQueuePriorityByMediaType")
        
        settings.setDefaultsIfNeeded()
        
        // Priority by media type should be enabled by default
        XCTAssertTrue(settings.autoQueuePriorityByMediaType)
    }
    
    func testAutoQueueSettings() {
        let settings = SettingsManager.shared
        
        // Test toggling auto-queue
        settings.autoQueueEnabled = false
        XCTAssertFalse(settings.autoQueueEnabled)
        
        settings.autoQueueEnabled = true
        XCTAssertTrue(settings.autoQueueEnabled)
        
        // Test toggling priority by media type
        settings.autoQueuePriorityByMediaType = false
        XCTAssertFalse(settings.autoQueuePriorityByMediaType)
        
        settings.autoQueuePriorityByMediaType = true
        XCTAssertTrue(settings.autoQueuePriorityByMediaType)
    }
    
    // MARK: - Drive Detection Tests
    
    func testOpticalDriveCreation() {
        let drive = OpticalDrive(
            mountPoint: "/Volumes/TEST_DISC",
            name: "Test Disc",
            type: .bluray4K,
            devicePath: "/dev/disk2"
        )
        
        XCTAssertEqual(drive.mountPoint, "/Volumes/TEST_DISC")
        XCTAssertEqual(drive.name, "Test Disc")
        XCTAssertEqual(drive.type, .bluray4K)
        XCTAssertEqual(drive.devicePath, "/dev/disk2")
    }
    
    func testOpticalDriveDisplayName() {
        let drive = OpticalDrive(
            mountPoint: "/Volumes/MATRIX",
            name: "The Matrix",
            type: .bluray4K,
            devicePath: "/dev/disk3"
        )
        
        XCTAssertEqual(drive.displayName, "The Matrix (/Volumes/MATRIX)")
    }
    
    func testDriveTypeEquality() {
        let drive1 = OpticalDrive(
            mountPoint: "/Volumes/DISC1",
            name: "Disc 1",
            type: .bluray,
            devicePath: "/dev/disk1"
        )
        
        let drive2 = OpticalDrive(
            mountPoint: "/Volumes/DISC2",
            name: "Disc 2",
            type: .bluray,
            devicePath: "/dev/disk2"
        )
        
        let drive3 = OpticalDrive(
            mountPoint: "/Volumes/DISC3",
            name: "Disc 3",
            type: .bluray4K,
            devicePath: "/dev/disk3"
        )
        
        XCTAssertEqual(drive1.type, drive2.type)
        XCTAssertNotEqual(drive1.type, drive3.type)
    }
    
    // MARK: - Priority Assignment Tests
    
    func testPriorityAssignmentFor4KBluray() {
        let drive = OpticalDrive(
            mountPoint: "/Volumes/UHD_DISC",
            name: "4K UHD Movie",
            type: .bluray4K,
            devicePath: "/dev/disk1"
        )
        
        let priority = drive.type.defaultPriority
        XCTAssertEqual(priority, .high, "4K Blu-ray should default to high priority")
    }
    
    func testPriorityAssignmentForRegularBluray() {
        let drive = OpticalDrive(
            mountPoint: "/Volumes/BLURAY",
            name: "Regular Blu-ray",
            type: .bluray,
            devicePath: "/dev/disk1"
        )
        
        let priority = drive.type.defaultPriority
        XCTAssertEqual(priority, .normal, "Regular Blu-ray should default to normal priority")
    }
    
    func testPriorityAssignmentForDVD() {
        let drive = OpticalDrive(
            mountPoint: "/Volumes/DVD",
            name: "DVD Movie",
            type: .dvd,
            devicePath: "/dev/disk1"
        )
        
        let priority = drive.type.defaultPriority
        XCTAssertEqual(priority, .low, "DVD should default to low priority")
    }
    
    func testPriorityAssignmentForHDDVD() {
        let drive = OpticalDrive(
            mountPoint: "/Volumes/HDDVD",
            name: "HD DVD",
            type: .hddvd,
            devicePath: "/dev/disk1"
        )
        
        let priority = drive.type.defaultPriority
        XCTAssertEqual(priority, .normal, "HD DVD should default to normal priority")
    }
    
    // MARK: - Auto-Queue Priority Logic Tests
    
    func testAutoQueueWithMediaTypePriority() {
        let settings = SettingsManager.shared
        settings.autoQueueEnabled = true
        settings.autoQueuePriorityByMediaType = true
        
        // 4K disc should get high priority
        let uhd = OpticalDrive(mountPoint: "/Volumes/UHD", name: "UHD", type: .bluray4K, devicePath: "/dev/disk1")
        XCTAssertEqual(uhd.type.defaultPriority, .high)
        
        // Regular Blu-ray should get normal priority
        let bluray = OpticalDrive(mountPoint: "/Volumes/BD", name: "BD", type: .bluray, devicePath: "/dev/disk2")
        XCTAssertEqual(bluray.type.defaultPriority, .normal)
        
        // DVD should get low priority
        let dvd = OpticalDrive(mountPoint: "/Volumes/DVD", name: "DVD", type: .dvd, devicePath: "/dev/disk3")
        XCTAssertEqual(dvd.type.defaultPriority, .low)
    }
    
    func testAutoQueueWithoutMediaTypePriority() {
        let settings = SettingsManager.shared
        settings.autoQueueEnabled = true
        settings.autoQueuePriorityByMediaType = false
        
        // When disabled, all should use normal priority (this would be tested in MainViewController)
        // The media type priorities still exist, but MainViewController should override to .normal
        XCTAssertFalse(settings.autoQueuePriorityByMediaType)
    }
    
    // MARK: - Queue Integration Tests
    
    func testQueueWithPriorityBasedOnMediaType() {
        let queue = ConversionQueue(testMode: true)
        let config = createTestConfiguration()
        
        // Add DVD (low priority)
        _ = queue.addJob(
            sourcePath: "/Volumes/DVD",
            outputDirectory: "/tmp/output",
            configuration: config,
            mediaType: .dvd,
            discTitle: "DVD Movie",
            priority: .low
        )
        
        // Add 4K Blu-ray (high priority)
        _ = queue.addJob(
            sourcePath: "/Volumes/UHD",
            outputDirectory: "/tmp/output",
            configuration: config,
            mediaType: .bluray4K,
            discTitle: "4K UHD Movie",
            priority: .high
        )
        
        // Add regular Blu-ray (normal priority)
        _ = queue.addJob(
            sourcePath: "/Volumes/BLURAY",
            outputDirectory: "/tmp/output",
            configuration: config,
            mediaType: .bluray,
            discTitle: "Blu-ray Movie",
            priority: .normal
        )
        
        let jobs = queue.getAllJobs()
        XCTAssertEqual(jobs.count, 3)
        
        // Sort by priority as the queue would
        let sortedJobs = jobs.sorted { job1, job2 in
            if job1.priority != job2.priority {
                return job1.priority > job2.priority
            }
            return job1.addedTime < job2.addedTime
        }
        
        // 4K should process first, then Blu-ray, then DVD
        XCTAssertEqual(sortedJobs[0].discTitle, "4K UHD Movie")
        XCTAssertEqual(sortedJobs[1].discTitle, "Blu-ray Movie")
        XCTAssertEqual(sortedJobs[2].discTitle, "DVD Movie")
    }
    
    // MARK: - Detection Logic Tests
    
    func testDriveDetectorSharedInstance() {
        let detector1 = DriveDetector.shared
        let detector2 = DriveDetector.shared
        
        XCTAssertTrue(detector1 === detector2, "DriveDetector should be a singleton")
    }
    
    func testDriveDetectorMonitoringControls() {
        let detector = DriveDetector.shared
        
        // Test starting monitoring
        detector.startMonitoring()
        // Can't directly test isMonitoring (private), but ensure no crash
        
        // Test stopping monitoring
        detector.stopMonitoring()
        // Again, ensure no crash
        
        // Test idempotency - starting multiple times should be safe
        detector.startMonitoring()
        detector.startMonitoring()
        detector.stopMonitoring()
    }
    
    // MARK: - Media Type String Representation Tests
    
    func testMediaTypeDescriptions() {
        let types: [(OpticalDrive.MediaType, String)] = [
            (.dvd, "DVD"),
            (.bluray, "Blu-ray"),
            (.bluray4K, "4K Blu-ray"),
            (.hddvd, "HD DVD"),
            (.unknown, "Unknown")
        ]
        
        for (type, expectedName) in types {
            XCTAssertEqual(type.displayName, expectedName, "\(type) display name should be '\(expectedName)'")
        }
    }
    
    // MARK: - Helper Methods
    
    private func createTestConfiguration() -> MediaRipper.RippingConfiguration {
        return MediaRipper.RippingConfiguration(
            outputDirectory: "/tmp/output",
            selectedTitles: [],
            videoCodec: .h264,
            audioCodec: .aac,
            quality: .medium,
            includeSubtitles: true,
            includeChapters: true,
            mediaType: nil
        )
    }
}
