import Foundation

/// Parser for Blu-ray index.bdmv and MovieObject.bdmv files
class BluRayIndexParser {
    
    private let blurayPath: String
    
    init(blurayPath: String) {
        self.blurayPath = blurayPath
    }
    
    // MARK: - Index Parsing
    
    func parseIndex() throws {
        let indexPath = blurayPath.appending("/BDMV/index.bdmv")
        
        guard let indexData = FileManager.default.contents(atPath: indexPath) else {
            throw BluRayParseError.indexNotFound
        }
        
        try parseIndexData(indexData)
    }
    
    private func parseIndexData(_ data: Data) throws {
        // Parse index.bdmv file
        let signature = String(data: data.subdata(in: 0..<4), encoding: .ascii) ?? ""
        
        guard signature == "INDX" else {
            throw BluRayParseError.invalidIndex
        }
        
        _ = String(data: data.subdata(in: 4..<8), encoding: .ascii) ?? ""
        
        // Parse AppInfoBDMV
        let appInfoOffset = data.readUInt32(at: 0x28)
        if appInfoOffset > 0 && appInfoOffset < data.count {
            try parseAppInfo(data: data, offset: Int(appInfoOffset))
        }
        
        // Parse index table
        let indexOffset = data.readUInt32(at: 0x2C)
        if indexOffset > 0 && indexOffset < data.count {
            try parseIndexTable(data: data, offset: Int(indexOffset))
        }
    }
    
    private func parseAppInfo(data: Data, offset: Int) throws {
        // Parse application info section
        _ = data.readUInt32(at: offset)
        
        // Video format, frame rate, etc.
        _ = data[offset + 5]
        _ = data[offset + 6]
    }
    
    private func parseIndexTable(data: Data, offset: Int) throws {
        // Parse index table for first play and top menu
        _ = data.readUInt32(at: offset)
        
        // First Play
        let firstPlayType = data[offset + 4]
        if firstPlayType == 1 { // Movie object
            _ = data.readUInt16(at: offset + 6)
        } else if firstPlayType == 2 { // BD-J object
            _ = data.readUInt16(at: offset + 6)
        }
        
        // Top Menu
        let topMenuType = data[offset + 8]
        if topMenuType == 1 { // Movie object
            _ = data.readUInt16(at: offset + 10)
        }
    }
    
    // MARK: - Movie Object Parsing
    
    func parseMovieObject() throws {
        let movieObjectPath = blurayPath.appending("/BDMV/MovieObject.bdmv")
        
        guard let movieData = FileManager.default.contents(atPath: movieObjectPath) else {
            // MovieObject.bdmv is optional
            return
        }
        
        try parseMovieObjectData(movieData)
    }
    
    private func parseMovieObjectData(_ data: Data) throws {
        let signature = String(data: data.subdata(in: 0..<4), encoding: .ascii) ?? ""
        
        guard signature == "MOBJ" else {
            throw BluRayParseError.invalidMovieObject
        }
        
        // Parse movie objects for navigation
        let objectCount = data.readUInt16(at: 0x0A)
        var currentOffset = 0x0C
        
        for _ in 0..<objectCount {
            if currentOffset + 12 <= data.count {
                // Parse movie object
                _ = data[currentOffset]
                _ = data[currentOffset + 1]
                _ = data[currentOffset + 2]
                
                currentOffset += 12
            }
        }
    }
}
