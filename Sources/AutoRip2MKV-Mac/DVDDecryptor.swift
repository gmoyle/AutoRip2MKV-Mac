import Foundation

#if canImport(Darwin)
import Darwin
#endif

/// DVD decryption handler using libdvdcss for CSS (Content Scramble System)
/// 
/// This implementation uses the open-source libdvdcss library to handle CSS decryption,
/// eliminating the need for a custom CSS implementation and ensuring legal compliance.
class DVDDecryptor {

    // CSS constants
    private static let SECTOR_SIZE = 2048
    private static let DVD_BLOCK_LEN = 2048

    // libdvdcss constants (from dvdcss.h)
    private static let DVDCSS_NOFLAGS: Int32 = 0
    private static let DVDCSS_READ_DECRYPT: Int32 = 1 << 0
    private static let DVDCSS_SEEK_KEY: Int32 = 1 << 1

    // Device reference for DVD drive
    private var devicePath: String
    private var dvdcss: OpaquePointer?

    init(devicePath: String) {
        self.devicePath = devicePath
    }

    deinit {
        closeDevice()
    }

    // MARK: - Public Interface

    /// Initialize DVD device and perform CSS authentication using libdvdcss
    func initializeDevice() throws {
        // Open device with libdvdcss
        let handle = dvdcss_open(devicePath)
        if handle == nil {
            throw DVDError.deviceNotFound
        }
        self.dvdcss = handle
        Logger.shared.log("libdvdcss: Successfully initialized device \(devicePath)")
    }

    /// Read and decrypt DVD sectors using libdvdcss
    func readSectors(startSector: UInt32, sectorCount: Int) throws -> Data {
        guard let handle = dvdcss else {
            throw DVDError.deviceNotOpen
        }

        // Seek to start sector with key retrieval
        let seekResult = dvdcss_seek(handle, Int32(startSector), Self.DVDCSS_SEEK_KEY)
        if seekResult < 0 {
            throw DVDError.invalidSector
        }

        // Allocate buffer
        var buffer = [UInt8](repeating: 0, count: sectorCount * Self.SECTOR_SIZE)
        
        // Read and decrypt sectors
        let readResult = buffer.withUnsafeMutableBytes { bufferPtr in
            dvdcss_read(handle, bufferPtr.baseAddress, Int32(sectorCount), Self.DVDCSS_READ_DECRYPT)
        }

        if readResult < 0 {
            throw DVDError.decryptionFailed
        }

        let bytesRead = Int(readResult) * Self.SECTOR_SIZE
        return Data(buffer[0..<bytesRead])
    }

    /// Close the DVD device
    func closeDevice() {
        if let handle = dvdcss {
            let _ = dvdcss_close(handle)
            self.dvdcss = nil
            Logger.shared.log("libdvdcss: Device closed")
        }
    }

    /// Decrypt a single sector (legacy interface for compatibility)
    func decryptSector(data: Data, sector: UInt32, titleNumber: Int) throws -> Data {
        // For libdvdcss, decryption happens during read
        // This method is for compatibility with existing code
        return data
    }

    /// Get title key (not needed with libdvdcss, but kept for compatibility)
    func getTitleKey(titleNumber: Int, startSector: UInt32) throws -> CSSKey {
        // libdvdcss handles keys internally
        return CSSKey()
    }

    /// Decrypt multiple sectors (compatibility wrapper)
    func decryptSectors(data: Data, titleKey: CSSKey, startSector: UInt32) throws -> Data {
        // libdvdcss handles decryption during read, so this just returns data
        return data
    }

    // MARK: - Helper Types

    /// CSS key structure (kept for compatibility)
    struct CSSKey {
        var key: [UInt8] = Array(repeating: 0, count: 5)
    }
}

// MARK: - libdvdcss C Function Declarations

/// C function declarations for libdvdcss
/// These map to the functions in dvdcss.h

@_silgen_name("dvdcss_open")
private func dvdcss_open(_ psz_target: UnsafePointer<CChar>?) -> OpaquePointer?

@_silgen_name("dvdcss_close")
private func dvdcss_close(_ dvdcss: OpaquePointer?) -> Int32

@_silgen_name("dvdcss_seek")
private func dvdcss_seek(_ dvdcss: OpaquePointer?, _ i_blocks: Int32, _ i_flags: Int32) -> Int32

@_silgen_name("dvdcss_read")
private func dvdcss_read(_ dvdcss: OpaquePointer?, _ p_buffer: UnsafeMutableRawPointer?, _ i_blocks: Int32, _ i_flags: Int32) -> Int32

// MARK: - Error Types

enum DVDError: Error {
    case deviceNotFound
    case deviceNotOpen
    case authenticationFailed
    case discKeyNotFound
    case titleKeyNotFound
    case decryptionFailed
    case invalidSector
    case cssNotSupported

    var localizedDescription: String {
        switch self {
        case .deviceNotFound:
            return "DVD device not found or libdvdcss failed to open device"
        case .deviceNotOpen:
            return "DVD device not opened"
        case .authenticationFailed:
            return "CSS authentication failed"
        case .discKeyNotFound:
            return "Disc key not found"
        case .titleKeyNotFound:
            return "Title key not found"
        case .decryptionFailed:
            return "Decryption failed"
        case .invalidSector:
            return "Invalid sector or seek failed"
        case .cssNotSupported:
            return "CSS encryption not supported (libdvdcss not available)"
        }
    }
}
