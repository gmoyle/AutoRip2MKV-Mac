import Foundation

/// Parser for DVD filesystem structure and title information
class DVDStructureParser {
    
    // DVD structure constants
    private static let VIDEO_TS_PATH = "VIDEO_TS"
    private static let IFO_EXTENSION = ".IFO"
    private static let VOB_EXTENSION = ".VOB"
    private static let BUP_EXTENSION = ".BUP"
    
    private var dvdPath: String
    private var titles: [DVDTitle] = []
    
    init(dvdPath: String) {
        self.dvdPath = dvdPath
    }
    
    // MARK: - Public Interface
    
    /// Parse the DVD structure and extract title information
    func parseDVDStructure() throws -> [DVDTitle] {
        let videoTSPath = dvdPath.appending("/\(Self.VIDEO_TS_PATH)")
        
        guard FileManager.default.fileExists(atPath: videoTSPath) else {
            throw DVDParseError.videoTSNotFound
        }
        
        try parseVMGI() // Video Manager Information
        try parseVTSFiles() // Video Title Set files
        
        return titles
    }
    
    /// Get main movie title (usually the longest)
    func getMainTitle() -> DVDTitle? {
        return titles.max { $0.duration < $1.duration }
    }
    
    /// Get all titles sorted by duration (longest first)
    func getTitlesSortedByDuration() -> [DVDTitle] {
        return titles.sorted { $0.duration > $1.duration }
    }
    
    // MARK: - VMGI Parsing
    
    private func parseVMGI() throws {
        let vmgiPath = dvdPath.appending("/\(Self.VIDEO_TS_PATH)/VIDEO_TS.IFO")
        
        guard let vmgiData = FileManager.default.contents(atPath: vmgiPath) else {
            throw DVDParseError.vmgiNotFound
        }
        
        try parseVMGIData(vmgiData)
    }
    
    private func parseVMGIData(_ data: Data) throws {
        // Parse VMGI (Video Manager Information)
        let identifier = String(data: data.subdata(in: 0..<12), encoding: .ascii) ?? ""
        
        guard identifier.hasPrefix("DVDVIDEO-VMG") else {
            throw DVDParseError.invalidVMGI
        }
        
        // Extract title count and information
        let titleCount = data.readUInt16(at: 0x3E)
        
        // Parse Title Table (TT_SRPT)
        let ttSrptOffset = data.readUInt32(at: 0xC4) * 2048
        if ttSrptOffset > 0 && ttSrptOffset < data.count {
            try parseTitleTable(data: data, offset: Int(ttSrptOffset))
        }
    }
    
    private func parseTitleTable(data: Data, offset: Int) throws {
        let titleCount = data.readUInt16(at: offset + 0)
        let tableEndAddress = data.readUInt32(at: offset + 4)
        
        var currentOffset = offset + 8
        
        for titleIndex in 0..<titleCount {
            if currentOffset + 12 <= data.count {
                let title = try parseTitleEntry(data: data, offset: currentOffset, titleNumber: Int(titleIndex + 1))
                titles.append(title)
                currentOffset += 12
            }
        }
    }
    
    private func parseTitleEntry(data: Data, offset: Int, titleNumber: Int) throws -> DVDTitle {
        let playbackType = data[offset]
        let numAngles = data[offset + 1]
        let numChapters = data.readUInt16(at: offset + 2)
        let parentalMask = data.readUInt16(at: offset + 4)
        let vtsNumber = data.readUInt16(at: offset + 6)
        let vtsTitleNumber = data.readUInt16(at: offset + 8)
        let startSector = data.readUInt32(at: offset + 10)
        
        let title = DVDTitle(
            number: titleNumber,
            vtsNumber: Int(vtsNumber),
            vtsTitleNumber: Int(vtsTitleNumber),
            startSector: startSector,
            chapters: Int(numChapters),
            angles: Int(numAngles),
            duration: 0 // Will be calculated from VTS
        )
        
        return title
    }
    
    // MARK: - VTS Parsing
    
    private func parseVTSFiles() throws {
        let videoTSPath = dvdPath.appending("/\(Self.VIDEO_TS_PATH)")
        
        for title in titles {
            try parseVTSForTitle(title, videoTSPath: videoTSPath)
        }
    }
    
    private func parseVTSForTitle(_ title: DVDTitle, videoTSPath: String) throws {
        let vtsFileName = String(format: "VTS_%02d_0.IFO", title.vtsNumber)
        let vtsPath = videoTSPath.appending("/\(vtsFileName)")
        
        guard let vtsData = FileManager.default.contents(atPath: vtsPath) else {
            return // Skip if VTS file not found
        }
        
        try parseVTSData(vtsData, for: title)
    }
    
    private func parseVTSData(_ data: Data, for title: DVDTitle) throws {
        // Parse VTS_xx_0.IFO file
        let identifier = String(data: data.subdata(in: 0..<12), encoding: .ascii) ?? ""
        
        guard identifier.hasPrefix("DVDVIDEO-VTS") else {
            throw DVDParseError.invalidVTS
        }
        
        // Parse PGCI (Program Chain Information)
        let pgciOffset = data.readUInt32(at: 0xCC) * 2048
        if pgciOffset > 0 && pgciOffset < data.count {
            try parsePGCI(data: data, offset: Int(pgciOffset), for: title)
        }
        
        // Parse VOB information
        try parseVOBInfo(data: data, for: title)
    }
    
    private func parsePGCI(data: Data, offset: Int, for title: DVDTitle) throws {
        // Parse Program Chain Information Table
        let pgcCount = data.readUInt16(at: offset)
        
        // Find the PGC for this title
        var currentOffset = offset + 8
        for _ in 0..<pgcCount {
            let pgcOffset = offset + Int(data.readUInt32(at: currentOffset + 4))
            
            if pgcOffset < data.count {
                try parsePGC(data: data, offset: pgcOffset, for: title)
                break // Use first PGC for now
            }
            
            currentOffset += 8
        }
    }
    
    private func parsePGC(data: Data, offset: Int, for title: DVDTitle) throws {
        // Parse individual Program Chain
        let programCount = data[offset + 2]
        let cellCount = data[offset + 3]
        let playbackTime = data.readUInt32(at: offset + 4)
        
        // Calculate duration from playback time (BCD format)
        let duration = decodeBCDTime(playbackTime)
        title.duration = duration
        
        // Parse cell information for chapter details
        let cellTableOffset = offset + Int(data.readUInt16(at: offset + 0xE8))
        try parseCells(data: data, offset: cellTableOffset, cellCount: Int(cellCount), for: title)
    }
    
    private func parseCells(data: Data, offset: Int, cellCount: Int, for title: DVDTitle) throws {
        var chapters: [DVDChapter] = []
        var currentOffset = offset
        
        for chapterIndex in 0..<cellCount {
            if currentOffset + 24 <= data.count {
                let cellType = data[currentOffset]
                let blockType = data[currentOffset + 1]
                let startSector = data.readUInt32(at: currentOffset + 4)
                let endSector = data.readUInt32(at: currentOffset + 8)
                
                let chapter = DVDChapter(
                    number: chapterIndex + 1,
                    startSector: startSector,
                    endSector: endSector,
                    duration: 0 // Calculate from sectors if needed
                )
                
                chapters.append(chapter)
                currentOffset += 24
            }
        }
        
        title.chapters = chapters
    }
    
    private func parseVOBInfo(data: Data, for title: DVDTitle) throws {
        // Parse VOB file information
        let vobFiles = try getVOBFiles(for: title.vtsNumber)
        title.vobFiles = vobFiles
    }
    
    private func getVOBFiles(for vtsNumber: Int) throws -> [String] {
        let videoTSPath = dvdPath.appending("/\(Self.VIDEO_TS_PATH)")
        var vobFiles: [String] = []
        
        // VTS VOB files are numbered VTS_xx_1.VOB, VTS_xx_2.VOB, etc.
        var vobIndex = 1
        while true {
            let vobFileName = String(format: "VTS_%02d_%d.VOB", vtsNumber, vobIndex)
            let vobPath = videoTSPath.appending("/\(vobFileName)")
            
            if FileManager.default.fileExists(atPath: vobPath) {
                vobFiles.append(vobPath)
                vobIndex += 1
            } else {
                break
            }
        }
        
        return vobFiles
    }
    
    // MARK: - Utility Functions
    
    private func decodeBCDTime(_ bcdTime: UInt32) -> TimeInterval {
        // Decode BCD (Binary Coded Decimal) time format
        let hours = Double((bcdTime >> 20) & 0xFF)
        let minutes = Double((bcdTime >> 12) & 0xFF)
        let seconds = Double((bcdTime >> 4) & 0xFF)
        let frames = Double(bcdTime & 0x0F)
        
        return hours * 3600 + minutes * 60 + seconds + frames / 25.0
    }
}

// MARK: - Data Extensions

extension Data {
    func readUInt16(at offset: Int) -> UInt16 {
        guard offset + 1 < count else { return 0 }
        return UInt16(self[offset]) << 8 | UInt16(self[offset + 1])
    }
    
    func readUInt32(at offset: Int) -> UInt32 {
        guard offset + 3 < count else { return 0 }
        return UInt32(self[offset]) << 24 |
               UInt32(self[offset + 1]) << 16 |
               UInt32(self[offset + 2]) << 8 |
               UInt32(self[offset + 3])
    }
}

// MARK: - DVD Data Structures

class DVDTitle {
    let number: Int
    let vtsNumber: Int
    let vtsTitleNumber: Int
    let startSector: UInt32
    let chaptersCount: Int
    let angles: Int
    var duration: TimeInterval
    var chapters: [DVDChapter] = []
    var vobFiles: [String] = []
    
    init(number: Int, vtsNumber: Int, vtsTitleNumber: Int, startSector: UInt32, 
         chapters: Int, angles: Int, duration: TimeInterval) {
        self.number = number
        self.vtsNumber = vtsNumber
        self.vtsTitleNumber = vtsTitleNumber
        self.startSector = startSector
        self.chaptersCount = chapters
        self.angles = angles
        self.duration = duration
    }
    
    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}

class DVDChapter {
    let number: Int
    let startSector: UInt32
    let endSector: UInt32
    let duration: TimeInterval
    
    init(number: Int, startSector: UInt32, endSector: UInt32, duration: TimeInterval) {
        self.number = number
        self.startSector = startSector
        self.endSector = endSector
        self.duration = duration
    }
    
    var sectorCount: UInt32 {
        return endSector - startSector + 1
    }
}

// MARK: - Error Types

enum DVDParseError: Error {
    case videoTSNotFound
    case vmgiNotFound
    case invalidVMGI
    case invalidVTS
    case corruptedStructure
    
    var localizedDescription: String {
        switch self {
        case .videoTSNotFound:
            return "VIDEO_TS directory not found"
        case .vmgiNotFound:
            return "VIDEO_TS.IFO file not found"
        case .invalidVMGI:
            return "Invalid VMGI structure"
        case .invalidVTS:
            return "Invalid VTS structure"
        case .corruptedStructure:
            return "DVD structure is corrupted"
        }
    }
}
