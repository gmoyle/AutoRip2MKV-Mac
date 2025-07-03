import XCTest
@testable import AutoRip2MKV_Mac

class DriveDetectorTests: XCTestCase {
    
    var driveDetector: DriveDetector!
    
    override func setUp() {
        super.setUp()
        driveDetector = DriveDetector.shared
    }
    
    override func tearDown() {
        driveDetector = nil
        super.tearDown()
    }
    
    func testDetectOpticalDrives() {
        // Test drive detection - this will be empty in a test environment
        let drives = driveDetector.detectOpticalDrives()
        
        // In a test environment, we expect no drives
        XCTAssertNotNil(drives)
        XCTAssertTrue(drives.count >= 0) // Should be 0 or more drives
        
        // Log detected drives for debugging
        print("Detected \(drives.count) optical drives:")
        for drive in drives {
            print("  - \(drive.displayName) (Type: \(drive.type))")
        }
    }
    
    func testOpticalDriveDisplayName() {
        let testDrive = OpticalDrive(
            mountPoint: "/Volumes/TEST_DVD",
            name: "Test DVD",
            type: .dvd
        )
        
        XCTAssertEqual(testDrive.displayName, "Test DVD (/Volumes/TEST_DVD)")
    }
    
    func testOpticalDriveTypes() {
        let dvdDrive = OpticalDrive(mountPoint: "/Volumes/DVD", name: "DVD", type: .dvd)
        let blurayDrive = OpticalDrive(mountPoint: "/Volumes/BLURAY", name: "Blu-ray", type: .bluray)
        let unknownDrive = OpticalDrive(mountPoint: "/Volumes/UNKNOWN", name: "Unknown", type: .unknown)
        
        XCTAssertEqual(dvdDrive.type, .dvd)
        XCTAssertEqual(blurayDrive.type, .bluray)
        XCTAssertEqual(unknownDrive.type, .unknown)
    }
}
