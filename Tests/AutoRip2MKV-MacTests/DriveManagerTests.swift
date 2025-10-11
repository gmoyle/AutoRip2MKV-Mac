import XCTest
@testable import AutoRip2MKV_Mac

final class DriveManagerTests: XCTestCase {
    
    var driveManager: DriveManager!
    var mockDriveDetector: MockDriveDetector!
    var mockSettingsManager: DriveManagerMockSettingsManager!
    
    override func setUpWithError() throws {
        mockDriveDetector = MockDriveDetector()
        mockSettingsManager = DriveManagerMockSettingsManager()
        driveManager = DriveManager(
            driveDetector: mockDriveDetector,
            settingsManager: mockSettingsManager
        )
    }
    
    override func tearDownWithError() throws {
        driveManager = nil
        mockDriveDetector = nil
        mockSettingsManager = nil
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        XCTAssertNotNil(driveManager)
        XCTAssertEqual(driveManager.availableDrives.count, 0)
        XCTAssertNil(driveManager.selectedDrive)
        XCTAssertEqual(driveManager.selectedDriveIndex, -1)
        XCTAssertFalse(driveManager.isDetecting)
    }
    
    // MARK: - Drive Detection Tests
    
    func testDetectOpticalDrives() async throws {
        // Setup mock drives
        let testDrives = createTestDrives()
        mockDriveDetector.mockDrives = testDrives
        
        // Perform detection
        let detectedDrives = await driveManager.detectOpticalDrives()
        
        // Verify results
        XCTAssertEqual(detectedDrives.count, testDrives.count)
        XCTAssertEqual(driveManager.availableDrives.count, testDrives.count)
        XCTAssertTrue(mockDriveDetector.detectOpticalDrivesCalled)
    }
    
    func testDetectOpticalDrivesCaching() async throws {
        // Setup mock drives
        let testDrives = createTestDrives()
        mockDriveDetector.mockDrives = testDrives
        
        // First detection
        _ = await driveManager.detectOpticalDrives()
        let firstCallCount = mockDriveDetector.detectOpticalDrivesCallCount
        
        // Second detection (should use cache)
        _ = await driveManager.detectOpticalDrives()
        let secondCallCount = mockDriveDetector.detectOpticalDrivesCallCount
        
        // Verify caching behavior
        XCTAssertEqual(firstCallCount, 1)
        XCTAssertEqual(secondCallCount, 1, "Second call should use cached results")
    }
    
    func testDetectOpticalDrivesPerformance() async throws {
        let testDrives = createTestDrives(count: 10)
        mockDriveDetector.mockDrives = testDrives
        
        measure {
            Task {
                _ = await driveManager.detectOpticalDrives()
            }
        }
    }
    
    // MARK: - Drive Selection Tests
    
    func testSelectDrive() async throws {
        // Setup drives
        let testDrives = createTestDrives()
        mockDriveDetector.mockDrives = testDrives
        await driveManager.detectOpticalDrives()
        
        // Select first drive
        let driveToSelect = testDrives[0]
        driveManager.selectDrive(driveToSelect)
        
        // Verify selection
        XCTAssertEqual(driveManager.selectedDrive?.devicePath, driveToSelect.devicePath)
        XCTAssertEqual(driveManager.selectedDriveIndex, 0)
        XCTAssertEqual(mockSettingsManager.selectedDriveIndex, 0)
    }
    
    func testSelectDriveByIndex() async throws {
        // Setup drives
        let testDrives = createTestDrives()
        mockDriveDetector.mockDrives = testDrives
        await driveManager.detectOpticalDrives()
        
        // Select by index
        driveManager.selectDrive(at: 1)
        
        // Verify selection
        XCTAssertEqual(driveManager.selectedDrive?.devicePath, testDrives[1].devicePath)
        XCTAssertEqual(driveManager.selectedDriveIndex, 1)
    }
    
    func testSelectDriveByInvalidIndex() async throws {
        // Setup drives
        let testDrives = createTestDrives()
        mockDriveDetector.mockDrives = testDrives
        await driveManager.detectOpticalDrives()
        
        // Try to select invalid index
        driveManager.selectDrive(at: 99)
        
        // Verify no selection occurred
        XCTAssertNil(driveManager.selectedDrive)
        XCTAssertEqual(driveManager.selectedDriveIndex, -1)
    }
    
    func testAutoSelectSingleDrive() async throws {
        // Setup single drive
        let singleDrive = [createTestDrives()[0]]
        mockDriveDetector.mockDrives = singleDrive
        
        // Perform detection
        _ = await driveManager.detectOpticalDrives()
        
        // Verify auto-selection
        XCTAssertEqual(driveManager.selectedDrive?.devicePath, singleDrive[0].devicePath)
        XCTAssertEqual(mockSettingsManager.selectedDriveIndex, 0)
    }
    
    // MARK: - Drive Ejection Tests
    
    func testEjectCurrentDriveWithSelection() async throws {
        // Setup drives and selection
        let testDrives = createTestDrives()
        mockDriveDetector.mockDrives = testDrives
        await driveManager.detectOpticalDrives()
        driveManager.selectDrive(testDrives[0])
        
        // Mock successful ejection
        mockDriveDetector.mockEjectionSuccess = true
        
        // Perform ejection
        do {
            try await driveManager.ejectCurrentDrive()
            // Should succeed without throwing
        } catch {
            XCTFail("Ejection should succeed: \(error)")
        }
    }
    
    func testEjectCurrentDriveWithoutSelection() async throws {
        // Try to eject without selection
        do {
            try await driveManager.ejectCurrentDrive()
            XCTFail("Should throw error when no drive selected")
        } catch DriveManagerError.noDriveSelected {
            // Expected error
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    // MARK: - Settings Integration Tests
    
    func testSettingsPersistence() async throws {
        // Setup drives
        let testDrives = createTestDrives()
        mockDriveDetector.mockDrives = testDrives
        await driveManager.detectOpticalDrives()
        
        // Select drive
        driveManager.selectDrive(at: 1)
        
        // Verify settings were saved
        XCTAssertEqual(mockSettingsManager.selectedDriveIndex, 1)
    }
    
    func testSettingsRestoration() async throws {
        // Setup saved selection
        mockSettingsManager.selectedDriveIndex = 1
        
        // Setup drives
        let testDrives = createTestDrives()
        mockDriveDetector.mockDrives = testDrives
        
        // Perform detection (should restore selection)
        _ = await driveManager.detectOpticalDrives()
        
        // Verify restoration
        XCTAssertEqual(driveManager.selectedDriveIndex, 1)
        XCTAssertEqual(driveManager.selectedDrive?.devicePath, testDrives[1].devicePath)
    }
    
    // MARK: - Delegate Tests
    
    func testDelegatePropertyPassthrough() {
        let testDelegate = MockDriveDetectorDelegate()
        
        driveManager.delegate = testDelegate
        
        XCTAssertTrue(driveManager.delegate === testDelegate)
        XCTAssertTrue(mockDriveDetector.delegate === testDelegate)
    }
    
    // MARK: - Error Handling Tests
    
    func testDriveManagerErrorDescriptions() {
        let errors: [DriveManagerError] = [
            .noDriveSelected,
            .ejectionFailed,
            .ejectionTimeout,
            .driveNotFound
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertNotNil(error.recoverySuggestion)
            XCTAssertFalse(error.errorDescription!.isEmpty)
            XCTAssertFalse(error.recoverySuggestion!.isEmpty)
        }
    }
    
    // MARK: - UI Helper Method Tests
    
    func testDisplayNameGeneration() async throws {
        let testDrives = createTestDrives()
        
        for drive in testDrives {
            let displayName = driveManager.displayName(for: drive)
            XCTAssertTrue(displayName.contains(drive.name))
            XCTAssertTrue(displayName.contains("DVD") || displayName.contains("Blu-ray"))
        }
    }
    
    func testDriveInfoGeneration() async throws {
        let testDrives = createTestDrives()
        
        for drive in testDrives {
            let driveInfo = driveManager.driveInfo(for: drive)
            XCTAssertTrue(driveInfo.contains(drive.displayName))
            XCTAssertTrue(driveInfo.contains(drive.devicePath))
            XCTAssertTrue(driveInfo.contains(drive.mountPoint))
        }
    }
    
    func testDriveAccessibility() {
        let accessibleDrive = OpticalDrive(
            mountPoint: "/", // Root should exist
            name: "Accessible Drive",
            type: .dvd,
            devicePath: "/dev/disk1"
        )
        
        let inaccessibleDrive = OpticalDrive(
            mountPoint: "/non/existent/path",
            name: "Inaccessible Drive",
            type: .dvd,
            devicePath: "/dev/disk99"
        )
        
        XCTAssertTrue(driveManager.isDriveAccessible(accessibleDrive))
        XCTAssertFalse(driveManager.isDriveAccessible(inaccessibleDrive))
    }
    
    // MARK: - Memory Management Tests
    
    func testMemoryManagement() {
        weak var weakDriveManager: DriveManager?
        
        autoreleasepool {
            let tempDriveManager = DriveManager(
                driveDetector: mockDriveDetector,
                settingsManager: mockSettingsManager
            )
            weakDriveManager = tempDriveManager
            // tempDriveManager goes out of scope here
        }
        
        // Should be deallocated
        XCTAssertNil(weakDriveManager)
    }
    
    // MARK: - Helper Methods
    
    private func createTestDrives(count: Int = 3) -> [OpticalDrive] {
        return (0..<count).map { index in
            OpticalDrive(
                mountPoint: "/Volumes/TestDrive\(index)",
                name: "Test Drive \(index)",
                type: index % 2 == 0 ? .dvd : .bluray,
                devicePath: "/dev/disk\(index)"
            )
        }
    }
}

// MARK: - Mock Classes

// Protocols are now defined in DriveManager.swift, no need to redefine them here

class MockDriveDetector: DriveDetecting {
    var mockDrives: [OpticalDrive] = []
    var detectOpticalDrivesCalled = false
    var detectOpticalDrivesCallCount = 0
    var mockEjectionSuccess = true
    
    var delegate: DriveDetectorDelegate?
    
    func detectOpticalDrives() -> [OpticalDrive] {
        detectOpticalDrivesCalled = true
        detectOpticalDrivesCallCount += 1
        return mockDrives
    }
    
    func ejectDrive(_ drive: OpticalDrive) -> Bool {
        return mockEjectionSuccess
    }
    
    func startMonitoring() {
        // Mock implementation - do nothing
    }
    
    func stopMonitoring() {
        // Mock implementation - do nothing
    }
}

class DriveManagerMockSettingsManager: SettingsManaging {
    var selectedDriveIndex: Int = -1
}

class MockDriveDetectorDelegate: NSObject, DriveDetectorDelegate {
    var didDetectNewDiscCalled = false
    var didEjectDiscCalled = false
    var lastDetectedDrive: OpticalDrive?
    var lastEjectedDrive: OpticalDrive?
    
    func driveDetector(_ detector: DriveDetector, didDetectNewDisc drive: OpticalDrive) {
        didDetectNewDiscCalled = true
        lastDetectedDrive = drive
    }
    
    func driveDetector(_ detector: DriveDetector, didEjectDisc drive: OpticalDrive) {
        didEjectDiscCalled = true
        lastEjectedDrive = drive
    }
}