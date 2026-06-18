import Foundation

// libdvdcss C function declarations via @_silgen_name
// These match the actual C signatures in <dvdcss/dvdcss.h>
@_silgen_name("dvdcss_open")
func dvdcss_open(_ psz_target: UnsafePointer<CChar>!) -> OpaquePointer?

@_silgen_name("dvdcss_close")
func dvdcss_close(_ dvdcss: OpaquePointer!) -> Int32

@_silgen_name("dvdcss_seek")
func dvdcss_seek(_ dvdcss: OpaquePointer!, _ i_blocks: Int32, _ i_flags: Int32) -> Int32

@_silgen_name("dvdcss_read")
func dvdcss_read(_ dvdcss: OpaquePointer!, _ p_buffer: UnsafeMutableRawPointer!, _ i_blocks: Int32, _ i_flags: Int32) -> Int32

private let DVDCSS_NOFLAGS: Int32    = 0
private let DVDCSS_READ_DECRYPT: Int32 = 1
private let DVDCSS_SEEK_MPEG: Int32  = 1
private let DVDCSS_SEEK_KEY: Int32   = 2
private let DVDCSS_BLOCK_SIZE        = 2048

/// DVD decryption handler using libdvdcss for real CSS decryption
class DVDDecryptor {

    private var devicePath: String
    private var dvdcss: OpaquePointer?

    struct CSSKey {
        var key: [UInt8] = Array(repeating: 0, count: 5)
    }

    private var titleKeys: [Int: CSSKey] = [:]

    init(devicePath: String) {
        self.devicePath = devicePath
    }

    deinit {
        closeDevice()
    }

    // MARK: - Public Interface

    func initializeDevice() throws {
        let handle = dvdcss_open(devicePath)
        guard handle != nil else {
            throw DVDError.deviceNotFound
        }
        self.dvdcss = handle
        print("[DVDDecryptor] libdvdcss opened device: \(devicePath)")
    }

    func getTitleKey(titleNumber: Int, startSector: UInt32) throws -> CSSKey {
        guard let css = dvdcss else { throw DVDError.deviceNotOpen }
        // Seek with DVDCSS_SEEK_KEY so libdvdcss negotiates the title key
        let result = dvdcss_seek(css, Int32(startSector), DVDCSS_SEEK_KEY)
        if result < 0 {
            print("[DVDDecryptor] Warning: seek+key failed for title \(titleNumber) at sector \(startSector)")
        }
        let key = CSSKey()
        titleKeys[titleNumber] = key
        return key
    }

    func closeDevice() {
        if let css = dvdcss {
            _ = dvdcss_close(css)
            self.dvdcss = nil
        }
    }

    /// Read and decrypt sectors using libdvdcss (seek then read with DVDCSS_READ_DECRYPT).
    /// If read fails, retries with DVDCSS_SEEK_KEY to renegotiate the title key
    /// (required when key changes between VOB files on some discs).
    func readAndDecryptSectors(startSector: UInt32, sectorCount: Int) throws -> Data {
        guard let css = dvdcss else { throw DVDError.deviceNotOpen }

        // Seek to position
        var seekResult = dvdcss_seek(css, Int32(startSector), DVDCSS_SEEK_MPEG)
        if seekResult < 0 {
            throw DVDError.invalidSector
        }

        let bufferSize = sectorCount * DVDCSS_BLOCK_SIZE
        var buffer = [UInt8](repeating: 0, count: bufferSize)

        var blocksRead = dvdcss_read(css, &buffer, Int32(sectorCount), DVDCSS_READ_DECRYPT)

        if blocksRead < 0 {
            // Title key may have changed (new VOB file). Re-seek with KEY flag and retry.
            print("[DVDDecryptor] Read failed at sector \(startSector), renegotiating title key...")
            seekResult = dvdcss_seek(css, Int32(startSector), DVDCSS_SEEK_KEY)
            if seekResult < 0 {
                throw DVDError.invalidSector
            }
            blocksRead = dvdcss_read(css, &buffer, Int32(sectorCount), DVDCSS_READ_DECRYPT)
            if blocksRead < 0 {
                throw DVDError.decryptionFailed
            }
        }

        let bytesRead = Int(blocksRead) * DVDCSS_BLOCK_SIZE
        return Data(buffer.prefix(bytesRead))
    }

    // Legacy API kept for compatibility — delegate to readAndDecryptSectors

    func readSectors(startSector: UInt32, sectorCount: Int) throws -> Data {
        return try readAndDecryptSectors(startSector: startSector, sectorCount: sectorCount)
    }

    func decryptSectors(data: Data, titleKey: CSSKey, startSector: UInt32) throws -> Data {
        return data
    }

    func decryptSector(data: Data, sector: UInt32, titleNumber: Int) throws -> Data {
        return data
    }
}

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
