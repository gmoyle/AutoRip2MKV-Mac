import Foundation

/// Parser for Blu-ray disc structure and playlist information
class BluRayStructureParser {

    // Blu-ray structure constants
    private static let BDMV_PATH = "BDMV"
    private static let PLAYLIST_PATH = "PLAYLIST"
    private static let STREAM_PATH = "STREAM"
    private static let CLIPINF_PATH = "CLIPINF"
    private static let AUXDATA_PATH = "AUXDATA"

    internal var blurayPath: String
    private var playlists: [BluRayPlaylist] = []
    private var clips: [BluRayClip] = []
    private var indexParser: BluRayIndexParser

    init(blurayPath: String) {
        self.blurayPath = blurayPath
        self.indexParser = BluRayIndexParser(blurayPath: blurayPath)
    }

    // MARK: - Public Interface

    /// Parse the Blu-ray structure and extract playlist information
    func parseBluRayStructure() throws -> [BluRayPlaylist] {
        let bdmvPath = blurayPath.appending("/\(Self.BDMV_PATH)")

        guard FileManager.default.fileExists(atPath: bdmvPath) else {
            throw BluRayParseError.bdmvNotFound
        }

        try indexParser.parseIndex() // Parse index.bdmv
        try indexParser.parseMovieObject() // Parse MovieObject.bdmv
        try parsePlaylists() // Parse playlist files
        try parseClipInfo() // Parse clip information

        return playlists
    }

    /// Get main movie playlist (usually the longest)
    func getMainPlaylist() -> BluRayPlaylist? {
        return playlists.max { $0.duration < $1.duration }
    }

    /// Get playlists sorted by duration (longest first)
    func getPlaylistsSortedByDuration() -> [BluRayPlaylist] {
        return playlists.sorted { $0.duration > $1.duration }
    }

    /// Get playlist by number
    func getPlaylist(number: Int) -> BluRayPlaylist? {
        return playlists.first { $0.number == number }
    }

    // MARK: - Playlist Parsing

    private func parsePlaylists() throws {
        let playlistPath = blurayPath.appending("/\(Self.BDMV_PATH)/\(Self.PLAYLIST_PATH)")

        guard FileManager.default.fileExists(atPath: playlistPath) else {
            throw BluRayParseError.playlistPathNotFound
        }

        let playlistFiles = try FileManager.default.contentsOfDirectory(atPath: playlistPath)

        for file in playlistFiles {
            if file.hasSuffix(".mpls") {
                let filePath = playlistPath.appending("/\(file)")
                try parsePlaylistFile(filePath, filename: file)
            }
        }
    }

    private func parsePlaylistFile(_ filePath: String, filename: String) throws {
        guard let data = FileManager.default.contents(atPath: filePath) else {
            return
        }

        let playlist = try parsePlaylistData(data, filename: filename)
        playlists.append(playlist)
    }

    private func parsePlaylistData(_ data: Data, filename: String) throws -> BluRayPlaylist {
        let signature = String(data: data.subdata(in: 0..<4), encoding: .ascii) ?? ""

        guard signature == "MPLS" else {
            throw BluRayParseError.invalidPlaylist
        }

        _ = String(data: data.subdata(in: 4..<8), encoding: .ascii) ?? ""

        // Extract playlist number from filename
        let playlistNumber = extractPlaylistNumber(from: filename)

        // Parse playlist info
        let playlistInfoOffset = data.readUInt32(at: 0x08)
        let playlistMarkOffset = data.readUInt32(at: 0x0C)
        _ = data.readUInt32(at: 0x10)

        var playlist = BluRayPlaylist(number: playlistNumber, filename: filename)

        // Parse playlist info section
        if playlistInfoOffset < data.count {
            try parsePlaylistInfo(data: data, offset: Int(playlistInfoOffset), playlist: &playlist)
        }

        // Parse playlist marks
        if playlistMarkOffset < data.count {
            try parsePlaylistMarks(data: data, offset: Int(playlistMarkOffset), playlist: &playlist)
        }

        return playlist
    }

    private func parsePlaylistInfo(data: Data, offset: Int, playlist: inout BluRayPlaylist) throws {
        _ = data.readUInt32(at: offset)

        // Playlist type and playback count
        _ = data[offset + 6]
        _ = data.readUInt16(at: offset + 8)

        // UO mask table (User Operation mask)
        _ = offset + 10

        // Playlist items
        let playItemCount = data.readUInt16(at: offset + 74)
        _ = data.readUInt16(at: offset + 76)

        var currentOffset = offset + 78

        // Parse play items
        for i in 0..<playItemCount {
            if currentOffset + 12 <= data.count {
                let playItem = try parsePlayItem(data: data, offset: currentOffset, index: Int(i))
                playlist.playItems.append(playItem)

                let itemLength = data.readUInt16(at: currentOffset)
                currentOffset += Int(itemLength)
            }
        }

        // Calculate total duration
        playlist.duration = playlist.playItems.reduce(0) { $0 + $1.duration }
    }

    private func parsePlayItem(data: Data, offset: Int, index: Int) throws -> BluRayPlayItem {
        _ = data.readUInt16(at: offset)

        // Clip information file name (5 characters + .clpi)
        let clipName = String(data: data.subdata(in: offset + 2..<offset + 7), encoding: .ascii) ?? ""

        // Connection condition and stc_id
        _ = data[offset + 12]
        _ = data[offset + 13]

        // In time and out time (45kHz ticks)
        let inTime = data.readUInt32(at: offset + 14)
        let outTime = data.readUInt32(at: offset + 18)

        // Calculate duration in seconds
        let duration = TimeInterval(outTime - inTime) / 45000.0

        // UO mask
        _ = offset + 22

        // Angle count
        let angleCount = data[offset + 86]

        let playItem = BluRayPlayItem(
            index: index,
            clipName: clipName,
            codecID: "H.264", // Default codec for BluRay
            inTime: inTime,
            outTime: outTime,
            duration: duration,
            angleCount: Int(angleCount)
        )

        return playItem
    }

    private func parsePlaylistMarks(data: Data, offset: Int, playlist: inout BluRayPlaylist) throws {
        _ = data.readUInt32(at: offset)
        let markCount = data.readUInt16(at: offset + 4)

        var currentOffset = offset + 6

        for i in 0..<markCount {
            if currentOffset + 14 <= data.count {
                let markType = data[currentOffset + 1]
                let playItemRef = data.readUInt16(at: currentOffset + 2)
                let markTime = data.readUInt32(at: currentOffset + 4)

                let mark = BluRayMark(
                    index: Int(i),
                    type: Int(markType),
                    playItemRef: Int(playItemRef),
                    time: markTime
                )

                playlist.marks.append(mark)
                currentOffset += 14
            }
        }
    }

    // MARK: - Clip Info Parsing

    private func parseClipInfo() throws {
        let clipInfoPath = blurayPath.appending("/\(Self.BDMV_PATH)/\(Self.CLIPINF_PATH)")

        guard FileManager.default.fileExists(atPath: clipInfoPath) else {
            return // ClipInfo is optional
        }

        let clipFiles = try FileManager.default.contentsOfDirectory(atPath: clipInfoPath)

        for file in clipFiles {
            if file.hasSuffix(".clpi") {
                let filePath = clipInfoPath.appending("/\(file)")
                try parseClipInfoFile(filePath, filename: file)
            }
        }
    }

    private func parseClipInfoFile(_ filePath: String, filename: String) throws {
        guard let data = FileManager.default.contents(atPath: filePath) else {
            return
        }

        let clip = try parseClipData(data, filename: filename)
        clips.append(clip)
    }

    private func parseClipData(_ data: Data, filename: String) throws -> BluRayClip {
        let signature = String(data: data.subdata(in: 0..<4), encoding: .ascii) ?? ""

        guard signature == "HDMV" else {
            throw BluRayParseError.invalidClipInfo
        }

        _ = String(data: data.subdata(in: 4..<8), encoding: .ascii) ?? ""

        // Extract clip name from filename
        let clipName = String(filename.dropLast(5)) // Remove .clpi extension

        // Parse clip info
        let clipInfoOffset = data.readUInt32(at: 0x08)
        _ = data.readUInt32(at: 0x0C)
        _ = data.readUInt32(at: 0x10)
        _ = data.readUInt32(at: 0x14)
        _ = data.readUInt32(at: 0x18)
        _ = data.readUInt32(at: 0x1C)

        var clip = BluRayClip(name: clipName, filename: filename)

        // Parse clip info section
        if clipInfoOffset < data.count {
            try parseClipInfoSection(data: data, offset: Int(clipInfoOffset), clip: &clip)
        }

        return clip
    }

    private func parseClipInfoSection(data: Data, offset: Int, clip: inout BluRayClip) throws {
        _ = data.readUInt32(at: offset)

        // Clip stream type and application type
        _ = data[offset + 5]
        _ = data[offset + 6]

        // TS recording rate
        _ = data.readUInt32(at: offset + 8)

        // Number of source packets
        _ = data.readUInt32(at: offset + 12)
    }

    // MARK: - Utility Functions

    private func extractPlaylistNumber(from filename: String) -> Int {
        // Extract number from filename like "00001.mpls"
        let nameWithoutExtension = String(filename.dropLast(5))
        return Int(nameWithoutExtension) ?? 0
    }

    /// Get stream files for a playlist
    func getStreamFiles(for playlist: BluRayPlaylist) -> [String] {
        let streamPath = blurayPath.appending("/\(Self.BDMV_PATH)/\(Self.STREAM_PATH)")
        var streamFiles: [String] = []

        for playItem in playlist.playItems {
            let streamFile = streamPath.appending("/\(playItem.clipName).m2ts")
            if FileManager.default.fileExists(atPath: streamFile) {
                streamFiles.append(streamFile)
            }
        }

        return streamFiles
    }
}

// MARK: - Blu-ray Data Structures

class BluRayPlaylist {
    let number: Int
    let filename: String
    var duration: TimeInterval = 0
    var playItems: [BluRayPlayItem] = []
    var marks: [BluRayMark] = []

    // Computed properties for MediaRipper compatibility
    var totalSize: UInt64 {
        // Estimate total size based on duration and bitrate
        // Blu-ray typically has ~36 Mbps for video+audio
        let estimatedBitrate: UInt64 = 36_000_000 // bits per second
        return UInt64(duration) * estimatedBitrate / 8 // bytes
    }

    var clips: [BluRayClip] {
        // Convert playItems to clips for compatibility
        return playItems.map { playItem in
            BluRayClip(name: playItem.clipName, filename: "\(playItem.clipName).m2ts")
        }
    }

    init(number: Int, filename: String) {
        self.number = number
        self.filename = filename
    }

    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    var chapterCount: Int {
        return marks.filter { $0.type == 1 }.count // Chapter marks
    }
}

class BluRayPlayItem {
    let index: Int
    let clipName: String
    let codecID: String
    let inTime: UInt32
    let outTime: UInt32
    let duration: TimeInterval
    let angleCount: Int

    init(index: Int, clipName: String, codecID: String, inTime: UInt32, outTime: UInt32, duration: TimeInterval, angleCount: Int) {
        self.index = index
        self.clipName = clipName
        self.codecID = codecID
        self.inTime = inTime
        self.outTime = outTime
        self.duration = duration
        self.angleCount = angleCount
    }
}

class BluRayMark {
    let index: Int
    let type: Int
    let playItemRef: Int
    let time: UInt32

    init(index: Int, type: Int, playItemRef: Int, time: UInt32) {
        self.index = index
        self.type = type
        self.playItemRef = playItemRef
        self.time = time
    }
}

class BluRayClip {
    let name: String
    let filename: String
    var bitrate: Int = 0

    init(name: String, filename: String) {
        self.name = name
        self.filename = filename
    }
}

// MARK: - Error Types

enum BluRayParseError: Error {
    case bdmvNotFound
    case indexNotFound
    case invalidIndex
    case invalidMovieObject
    case playlistPathNotFound
    case invalidPlaylist
    case invalidClipInfo
    case corruptedStructure

    var localizedDescription: String {
        switch self {
        case .bdmvNotFound:
            return "BDMV directory not found"
        case .indexNotFound:
            return "index.bdmv file not found"
        case .invalidIndex:
            return "Invalid index.bdmv structure"
        case .invalidMovieObject:
            return "Invalid MovieObject.bdmv structure"
        case .playlistPathNotFound:
            return "PLAYLIST directory not found"
        case .invalidPlaylist:
            return "Invalid playlist structure"
        case .invalidClipInfo:
            return "Invalid clip info structure"
        case .corruptedStructure:
            return "Blu-ray structure is corrupted"
        }
    }
}
