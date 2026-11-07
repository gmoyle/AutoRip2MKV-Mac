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
        _ = data.readUInt16(at: 0x3E)

        // Parse Title Table (TT_SRPT)
        let ttSrptOffset = data.readUInt32(at: 0xC4) * 2048
        if ttSrptOffset > 0 && ttSrptOffset < data.count {
            try parseTitleTable(data: data, offset: Int(ttSrptOffset))
        }
    }

    private func parseTitleTable(data: Data, offset: Int) throws {
        let titleCount = data.readUInt16(at: offset + 0)
        _ = data.readUInt32(at: offset + 4)

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
        // TT_SRPT entry is 12 bytes (DVD spec):
        // [0] title_category  [1] angles  [2-3] num_ptts(chapters)
        // [4-5] parental_id   [6] vts_nr  [7] vts_ttn  [8-11] start_sector
        let numAngles = data[offset + 1]
        let numChapters = data.readUInt16(at: offset + 2)
        let vtsNumber = data[offset + 6]
        let vtsTitleNumber = data[offset + 7]
        let startSector = data.readUInt32(at: offset + 8)

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

        // Track language codes for audio/subtitle labeling
        parseTrackLanguages(data: data, for: title)

        // Parse VOB information
        try parseVOBInfo(data: data, for: title)
    }

    /// Extract audio and subtitle language codes from the VTSI MAT.
    /// Audio attributes: count at 0x202, 8-byte entries from 0x204 (lang code at +2).
    /// Subpicture attributes: count at 0x254, 6-byte entries from 0x256 (lang code at +2).
    private func parseTrackLanguages(data: Data, for title: DVDTitle) {
        func langCode(at offset: Int) -> String? {
            guard offset + 1 < data.count else { return nil }
            let chars = [data[offset], data[offset + 1]].map { byte -> Character? in
                let lower = (byte >= 0x41 && byte <= 0x5A) ? byte + 0x20 : byte
                guard lower >= 0x61, lower <= 0x7A else { return nil }
                return Character(UnicodeScalar(lower))
            }
            guard let c1 = chars[0], let c2 = chars[1] else { return nil }
            return String([c1, c2])
        }

        let audioCount = min(Int(data.readUInt16(at: 0x202)), 8)
        for i in 0..<audioCount {
            title.audioLanguages.append(langCode(at: 0x204 + i * 8 + 2) ?? "")
        }

        let subpCount = min(Int(data.readUInt16(at: 0x254)), 32)
        for i in 0..<subpCount {
            title.subtitleLanguages.append(langCode(at: 0x256 + i * 6 + 2) ?? "")
        }
    }

    private func parsePGCI(data: Data, offset: Int, for title: DVDTitle) throws {
        // Parse Program Chain Information Table. The title's PGC comes from the
        // VTS_PTT_SRPT (first part-of-title's PGC number); fall back to treating
        // the VTS title number as the PGC number if that table is unreadable.
        let pgcCount = data.readUInt16(at: offset)
        let targetPGC = Self.pgcNumber(forVTSTitle: title.vtsTitleNumber, vtsi: data)
            ?? max(1, title.vtsTitleNumber)
        let pgcIndex = min(targetPGC - 1, max(0, Int(pgcCount) - 1))

        let entryOffset = offset + 8 + pgcIndex * 8
        let pgcOffset = offset + Int(data.readUInt32(at: entryOffset + 4))

        if pgcOffset > 0 && pgcOffset < data.count {
            try parsePGC(data: data, offset: pgcOffset, for: title)
        }
    }

    private func parsePGC(data: Data, offset: Int, for title: DVDTitle) throws {
        // Parse individual Program Chain
        _ = data[offset + 2]
        let cellCount = data[offset + 3]
        let playbackTime = data.readUInt32(at: offset + 4)

        // Calculate duration from playback time (BCD format)
        let duration = decodeBCDTime(playbackTime)
        title.duration = duration

        // Parse cell information for chapter details
        let cellTableOffset = offset + Int(data.readUInt16(at: offset + 0xE8))
        try parseCells(data: data, offset: cellTableOffset, cellCount: Int(cellCount), for: title)
    }

    /// PGC number (1-based) of a VTS title's first part-of-title, from the
    /// VTS_PTT_SRPT table (sector pointer at VTSI 0xC8), or nil if unreadable.
    static func pgcNumber(forVTSTitle vtsTitle: Int, vtsi data: Data) -> Int? {
        guard data.count >= 0xCC, vtsTitle >= 1 else { return nil }
        let ptt = Int(data.readUInt32(at: 0xC8)) * 2048
        guard ptt > 0, ptt + 8 <= data.count else { return nil }
        let titleCount = Int(data.readUInt16(at: ptt))
        guard vtsTitle <= titleCount, ptt + 8 + vtsTitle * 4 <= data.count else { return nil }
        let entry = ptt + Int(data.readUInt32(at: ptt + 8 + (vtsTitle - 1) * 4))
        guard entry + 2 <= data.count else { return nil }
        let pgcn = Int(data.readUInt16(at: entry))
        return pgcn >= 1 ? pgcn : nil
    }

    /// Cell playback table: 24-byte entries. Byte 0 is the cell category
    /// (bits 7–6 block mode, 5–4 block type; type 1 = angle block). +8 is the
    /// first VOBU's start sector and +20 the last VOBU's end sector, both
    /// relative to the start of the title set's title VOBs (VTS_xx_1.VOB).
    private func parseCells(data: Data, offset: Int, cellCount: Int, for title: DVDTitle) throws {
        var chapters: [DVDChapter] = []
        var cells: [(category: UInt8, first: UInt32, last: UInt32)] = []
        var currentOffset = offset

        for chapterIndex in 0..<cellCount {
            if currentOffset + 24 <= data.count {
                let category = data[currentOffset]
                let startSector = data.readUInt32(at: currentOffset + 8)
                let endSector = data.readUInt32(at: currentOffset + 20)

                chapters.append(DVDChapter(
                    number: chapterIndex + 1,
                    startSector: startSector,
                    endSector: endSector,
                    duration: 0 // Calculate from sectors if needed
                ))
                cells.append((category, startSector, endSector))
                currentOffset += 24
            }
        }

        title.chapters = chapters
        title.cellRanges = Self.sectorRanges(ofCells: cells)
    }

    /// The VOBS-relative sector ranges to read for a PGC's cells, in playback
    /// order: later angles of a multi-angle block are skipped (only the first
    /// angle is ripped), malformed cells dropped, and contiguous or overlapping
    /// ranges merged.
    static func sectorRanges(ofCells cells: [(category: UInt8, first: UInt32, last: UInt32)])
        -> [ClosedRange<UInt32>] {
        var ranges: [ClosedRange<UInt32>] = []
        for cell in cells {
            let blockMode = cell.category >> 6          // 0 none, 1 first, 2 middle, 3 last
            let blockType = (cell.category >> 4) & 0x3  // 1 = angle block
            if blockType == 1 && blockMode > 1 { continue }
            guard cell.last >= cell.first else { continue }
            if let previous = ranges.last,
               cell.first >= previous.lowerBound,
               cell.first <= previous.upperBound &+ 1 {
                ranges[ranges.count - 1] = previous.lowerBound...max(previous.upperBound, cell.last)
            } else {
                ranges.append(cell.first...cell.last)
            }
        }
        return ranges
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
        // DVD IFO stores playback time as 4 BCD bytes: HH MM SS FF
        // Each byte: upper nibble = tens digit, lower nibble = units digit
        func bcd(_ byte: UInt32) -> Double {
            return Double((byte >> 4) & 0xF) * 10 + Double(byte & 0xF)
        }
        let hours   = bcd((bcdTime >> 24) & 0xFF)
        let minutes = bcd((bcdTime >> 16) & 0xFF)
        let seconds = bcd((bcdTime >> 8) & 0xFF)
        let frames  = bcd(bcdTime & 0xFF)
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
    /// Sector ranges of this title's cells, relative to the start of its title
    /// set's title VOBs (VTS_xx_1.VOB), in playback order. Empty if the IFO
    /// couldn't be parsed; the ripper then falls back to the whole VOB set.
    var cellRanges: [ClosedRange<UInt32>] = []
    var vobFiles: [String] = []
    // ISO 639-1 codes from the VTS IFO, in stream order ("" when unspecified)
    var audioLanguages: [String] = []
    var subtitleLanguages: [String] = []

    // Computed property for sectors - calculate from chapters or estimate
    var sectors: UInt32 {
        if !chapters.isEmpty {
            return chapters.last?.endSector ?? startSector
        }
        // Estimate based on duration (rough approximation)
        return UInt32(duration * 25) // ~25 sectors per second for DVD
    }

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

enum DVDParseError: LocalizedError {
    case videoTSNotFound
    case vmgiNotFound
    case invalidVMGI
    case invalidVTS
    case corruptedStructure

    var errorDescription: String? {
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
