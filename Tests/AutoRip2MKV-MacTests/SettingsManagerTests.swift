import XCTest
@testable import AutoRip2MKV_Mac

class SettingsManagerTests: XCTestCase {
    
    var settingsManager: SettingsManager!
    
    override func setUp() {
        super.setUp()
        settingsManager = SettingsManager.shared
        
        // Clear any existing settings for testing
        clearTestSettings()
    }
    
    override func tearDown() {
        clearTestSettings()
        settingsManager = nil
        super.tearDown()
    }
    
    private func clearTestSettings() {
        UserDefaults.standard.removeObject(forKey: "lastSourcePath")
        UserDefaults.standard.removeObject(forKey: "lastOutputPath")
        UserDefaults.standard.removeObject(forKey: "selectedDriveIndex")
    }
    
    func testSourcePathPersistence() {
        // Test setting and getting source path
        let testPath = "/Volumes/TEST_DVD"
        settingsManager.lastSourcePath = testPath
        
        XCTAssertEqual(settingsManager.lastSourcePath, testPath)
        
        // Test nil value
        settingsManager.lastSourcePath = nil
        XCTAssertNil(settingsManager.lastSourcePath)
    }
    
    func testOutputPathPersistence() {
        // Test setting and getting output path
        let testPath = "/Users/test/Movies"
        settingsManager.lastOutputPath = testPath
        
        XCTAssertEqual(settingsManager.lastOutputPath, testPath)
        
        // Test nil value
        settingsManager.lastOutputPath = nil
        XCTAssertNil(settingsManager.lastOutputPath)
    }
    
    func testSelectedDriveIndexPersistence() {
        // Test setting and getting drive index
        let testIndex = 2
        settingsManager.selectedDriveIndex = testIndex
        
        XCTAssertEqual(settingsManager.selectedDriveIndex, testIndex)
        
        // Test default value (should be 0)
        clearTestSettings()
        XCTAssertEqual(settingsManager.selectedDriveIndex, 0)
    }
    
    func testSaveSettingsConvenienceMethod() {
        let sourcePath = "/Volumes/TEST_DVD"
        let outputPath = "/Users/test/Movies"
        let driveIndex = 1
        
        settingsManager.saveSettings(
            sourcePath: sourcePath,
            outputPath: outputPath,
            driveIndex: driveIndex
        )
        
        XCTAssertEqual(settingsManager.lastSourcePath, sourcePath)
        XCTAssertEqual(settingsManager.lastOutputPath, outputPath)
        XCTAssertEqual(settingsManager.selectedDriveIndex, driveIndex)
    }
    
    func testSaveSettingsWithNilValues() {
        // First set some values
        settingsManager.saveSettings(
            sourcePath: "/test",
            outputPath: "/test",
            driveIndex: 1
        )
        
        // Then save with nil values
        settingsManager.saveSettings(
            sourcePath: nil,
            outputPath: nil,
            driveIndex: 0
        )
        
        XCTAssertNil(settingsManager.lastSourcePath)
        XCTAssertNil(settingsManager.lastOutputPath)
        XCTAssertEqual(settingsManager.selectedDriveIndex, 0)
    }
}
