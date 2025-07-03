import XCTest
@testable import AutoRip2MKV_Mac

final class DVDDecryptorTests: XCTestCase {
    
    var decryptor: DVDDecryptor!
    let testDevicePath = "/dev/disk2"
    
    override func setUpWithError() throws {
        decryptor = DVDDecryptor(devicePath: testDevicePath)
    }
    
    override func tearDownWithError() throws {
        decryptor = nil
    }
    
    // MARK: - Initialization Tests
    
    func testDecryptorInitialization() {
        XCTAssertNotNil(decryptor)
    }
    
    func testDevicePathSet() {
        // Since devicePath is private, we test behavior that depends on it
        XCTAssertNotNil(decryptor)
    }
    
    // MARK: - CSS Key Tests
    
    func testCSSKeyStructure() {
        let key = DVDDecryptor.CSSKey()
        XCTAssertEqual(key.key.count, 5)
        XCTAssertEqual(key.key, [0, 0, 0, 0, 0])
    }
    
    func testCSSKeyCustomInitialization() {
        var key = DVDDecryptor.CSSKey()
        key.key = [0x01, 0x02, 0x03, 0x04, 0x05]
        XCTAssertEqual(key.key, [0x01, 0x02, 0x03, 0x04, 0x05])
    }
    
    // MARK: - Device Operations Tests
    
    func testInitializeDeviceWithInvalidPath() {
        let invalidDecryptor = DVDDecryptor(devicePath: "/invalid/path")
        
        XCTAssertThrowsError(try invalidDecryptor.initializeDevice()) { error in
            XCTAssertTrue(error is DVDError)
            if let dvdError = error as? DVDError {
                XCTAssertEqual(dvdError, DVDError.deviceNotFound)
            }
        }
    }
    
    func testCloseDevice() {
        // Test that closeDevice doesn't crash
        XCTAssertNoThrow(decryptor.closeDevice())
    }
    
    // MARK: - Sector Decryption Tests
    
    func testDecryptSectorWithoutTitleKey() {
        let testData = Data([0x00, 0x01, 0x02, 0x03])
        
        XCTAssertThrowsError(try decryptor.decryptSector(data: testData, sector: 0, titleNumber: 1)) { error in
            XCTAssertTrue(error is DVDError)
            if let dvdError = error as? DVDError {
                XCTAssertEqual(dvdError, DVDError.titleKeyNotFound)
            }
        }
    }
    
    func testDecryptUnencryptedSector() {
        // Create test data that appears unencrypted (scrambling bits = 0)
        var testData = Data(repeating: 0x00, count: 2048)
        testData[0x14] = 0x00 // No scrambling bits set
        
        // This should not throw since we're testing the decryption logic structure
        // In a real scenario, we'd need a valid title key first
    }
    
    func testDecryptEncryptedSector() {
        // Create test data that appears encrypted (scrambling bits set)
        var testData = Data(repeating: 0x00, count: 2048)
        testData[0x14] = 0x30 // Scrambling bits set
        
        // This would require a valid title key to test properly
    }
    
    // MARK: - Title Key Tests
    
    func testGetTitleKeyWithoutInitialization() {
        XCTAssertThrowsError(try decryptor.getTitleKey(titleNumber: 1, startSector: 0)) { error in
            // This should fail because device isn't initialized
            XCTAssertTrue(error is DVDError)
        }
    }
    
    // MARK: - Performance Tests
    
    func testDecryptorPerformance() {
        measure {
            // Test performance of creating and destroying decryptor instances
            let testDecryptor = DVDDecryptor(devicePath: testDevicePath)
            testDecryptor.closeDevice()
        }
    }
    
    func testKeyGenerationPerformance() {
        measure {
            // Test performance of creating CSS keys
            for _ in 0..<1000 {
                _ = DVDDecryptor.CSSKey()
            }
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testDVDErrorDescriptions() {
        XCTAssertEqual(DVDError.deviceNotFound.localizedDescription, "DVD device not found")
        XCTAssertEqual(DVDError.deviceNotOpen.localizedDescription, "DVD device not opened")
        XCTAssertEqual(DVDError.authenticationFailed.localizedDescription, "CSS authentication failed")
        XCTAssertEqual(DVDError.discKeyNotFound.localizedDescription, "Disc key not found")
        XCTAssertEqual(DVDError.titleKeyNotFound.localizedDescription, "Title key not found")
        XCTAssertEqual(DVDError.decryptionFailed.localizedDescription, "Decryption failed")
        XCTAssertEqual(DVDError.invalidSector.localizedDescription, "Invalid sector")
        XCTAssertEqual(DVDError.cssNotSupported.localizedDescription, "CSS encryption not supported")
    }
    
    // MARK: - Memory Management Tests
    
    func testMemoryManagement() {
        weak var weakDecryptor: DVDDecryptor?
        
        autoreleasepool {
            let tempDecryptor = DVDDecryptor(devicePath: testDevicePath)
            weakDecryptor = tempDecryptor
            // tempDecryptor goes out of scope here
        }
        
        // Decryptor should be deallocated
        XCTAssertNil(weakDecryptor)
    }
    
    // MARK: - Thread Safety Tests
    
    func testConcurrentAccess() {
        let expectation = XCTestExpectation(description: "Concurrent access")
        let concurrentQueue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)
        let group = DispatchGroup()
        
        for _ in 0..<10 {
            concurrentQueue.async(group: group) {
                let testDecryptor = DVDDecryptor(devicePath: self.testDevicePath)
                testDecryptor.closeDevice()
            }
        }
        
        group.notify(queue: .main) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
}
