import Foundation
import os.log

/// Comprehensive logging system for AutoRip2MKV
/// Provides detailed error tracking and file output for debugging ripping issues
class Logger {
    
    // MARK: - Log Levels
    
    enum LogLevel: String, CaseIterable {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
        case critical = "CRITICAL"
        
        var osLogType: OSLogType {
            switch self {
            case .debug: return .debug
            case .info: return .info
            case .warning: return .default
            case .error: return .error
            case .critical: return .fault
            }
        }
    }
    
    // MARK: - Log Categories
    
    enum Category: String, CaseIterable {
        case general = "General"
        case dvdRipping = "DVD_Ripping"
        case blurayRipping = "BluRay_Ripping"
        case conversion = "Conversion"
        case queue = "Queue"
        case diskOperations = "Disk_Operations"
        case ffmpeg = "FFmpeg"
        case css = "CSS_Decryption"
        case filesystem = "FileSystem"
        case ui = "UI"
        case performance = "Performance"
        
        var osLog: OSLog {
            return OSLog(subsystem: "com.gmoyle.AutoRip2MKV", category: self.rawValue)
        }
    }
    
    // MARK: - Properties
    
    static let shared = Logger()
    
    private let fileManager = FileManager.default
    private let logFileURL: URL
    private let sessionLogFileURL: URL
    private let errorLogFileURL: URL
    private let maxLogFileSize: Int64 = 10 * 1024 * 1024 // 10MB
    private let maxLogFiles = 5
    
    private let logQueue = DispatchQueue(label: "com.autoRip2MKV.logger", qos: .utility)
    private let dateFormatter: DateFormatter
    
    // MARK: - Initialization
    
    private init() {
        self.dateFormatter = DateFormatter()
        self.dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        
        // Create log directory in Application Support
        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let logDirectory = appSupportURL.appendingPathComponent("AutoRip2MKV-Mac/Logs")
        
        try? fileManager.createDirectory(at: logDirectory, withIntermediateDirectories: true)
        
        // Set up log file URLs
        let sessionId = UUID().uuidString.prefix(8)
        let timestamp = DateFormatter().string(from: Date())
        DateFormatter().dateFormat = "yyyy-MM-dd_HH-mm-ss"
        
        self.logFileURL = logDirectory.appendingPathComponent("AutoRip2MKV.log")
        self.sessionLogFileURL = logDirectory.appendingPathComponent("Session_\(timestamp)_\(sessionId).log")
        self.errorLogFileURL = logDirectory.appendingPathComponent("Errors.log")
        
        // Initialize log files
        initializeLogFiles()
        
        // Log session start
        log("=" * 80, level: .info, category: .general)
        log("AutoRip2MKV Session Started", level: .info, category: .general)
        log("Session ID: \(sessionId)", level: .info, category: .general)
        log("Log Directory: \(logDirectory.path)", level: .info, category: .general)
        log("=" * 80, level: .info, category: .general)
    }
    
    // MARK: - Public Logging Methods
    
    /// Log a message with specified level and category
    func log(_ message: String, level: LogLevel = .info, category: Category = .general, file: String = #file, function: String = #function, line: Int = #line) {
        let logEntry = createLogEntry(message: message, level: level, category: category, file: file, function: function, line: line)
        
        logQueue.async {
            self.writeToFile(entry: logEntry, level: level)
            self.writeToSystemLog(entry: logEntry, level: level, category: category)
        }
    }
    
    /// Log an error with detailed information
    func logError(_ error: Error, context: String = "", category: Category = .general, file: String = #file, function: String = #function, line: Int = #line) {
        let errorMessage = formatError(error, context: context)
        log(errorMessage, level: .error, category: category, file: file, function: function, line: line)
    }
    
    /// Log DVD ripping specific events
    func logDVDRipping(_ message: String, level: LogLevel = .info, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: level, category: .dvdRipping, file: file, function: function, line: line)
    }
    
    /// Log FFmpeg related events
    func logFFmpeg(_ message: String, level: LogLevel = .info, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: level, category: .ffmpeg, file: file, function: function, line: line)
    }
    
    /// Log queue operations
    func logQueue(_ message: String, level: LogLevel = .info, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: level, category: .queue, file: file, function: function, line: line)
    }
    
    /// Log conversion progress with detailed information
    func logConversionProgress(jobId: UUID, progress: Double, currentItem: String?, totalItems: Int, ffmpegOutput: String? = nil) {
        var message = "Conversion Progress - Job: \(jobId.uuidString.prefix(8)), Progress: \(String(format: "%.1f%%", progress * 100))"
        
        if let item = currentItem {
            message += ", Current: \(item)"
        }
        
        message += ", Total Items: \(totalItems)"
        
        if let output = ffmpegOutput {
            message += "\nFFmpeg Output: \(output)"
        }
        
        log(message, level: .debug, category: .conversion)
    }
    
    /// Log system information for debugging
    func logSystemInfo() {
        log("System Information:", level: .info, category: .general)
        log("macOS Version: \(ProcessInfo.processInfo.operatingSystemVersionString)", level: .info, category: .general)
        log("Hardware: \(ProcessInfo.processInfo.machineHardwareName)", level: .info, category: .general)
        log("Memory: \(ProcessInfo.processInfo.physicalMemory / 1024 / 1024 / 1024) GB", level: .info, category: .general)
        log("CPU Count: \(ProcessInfo.processInfo.processorCount)", level: .info, category: .general)
        
        // Log available disk space
        if let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            do {
                let resourceValues = try documentsURL.resourceValues(forKeys: [.volumeAvailableCapacityKey])
                if let capacity = resourceValues.volumeAvailableCapacity {
                    log("Available Disk Space: \(ByteCountFormatter.string(fromByteCount: Int64(capacity), countStyle: .file))", level: .info, category: .general)
                }
            } catch {
                logError(error, context: "Failed to get disk space information", category: .filesystem)
            }
        }
    }
    
    /// Log FFmpeg command execution
    func logFFmpegCommand(_ command: [String], workingDirectory: String? = nil) {
        let commandString = command.joined(separator: " ")
        log("Executing FFmpeg Command:", level: .info, category: .ffmpeg)
        log("Command: \(commandString)", level: .info, category: .ffmpeg)
        
        if let workingDir = workingDirectory {
            log("Working Directory: \(workingDir)", level: .info, category: .ffmpeg)
        }
    }
    
    /// Log CSS decryption details
    func logCSS(_ message: String, level: LogLevel = .info, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: level, category: .css, file: file, function: function, line: line)
    }
    
    /// Log performance metrics
    func logPerformance(_ message: String, duration: TimeInterval? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        var fullMessage = message
        if let duration = duration {
            fullMessage += " (Duration: \(String(format: "%.3f", duration))s)"
        }
        log(fullMessage, level: .info, category: .performance, file: file, function: function, line: line)
    }
    
    // MARK: - Private Methods
    
    private func initializeLogFiles() {
        let initialMessage = "AutoRip2MKV Log File - \(dateFormatter.string(from: Date()))\n"
        
        // Initialize main log file
        if !fileManager.fileExists(atPath: logFileURL.path) {
            try? initialMessage.write(to: logFileURL, atomically: true, encoding: .utf8)
        }
        
        // Initialize session log file
        try? initialMessage.write(to: sessionLogFileURL, atomically: true, encoding: .utf8)
        
        // Initialize error log file
        if !fileManager.fileExists(atPath: errorLogFileURL.path) {
            try? initialMessage.write(to: errorLogFileURL, atomically: true, encoding: .utf8)
        }
        
        // Clean up old log files
        cleanupOldLogFiles()
    }
    
    private func createLogEntry(message: String, level: LogLevel, category: Category, file: String, function: String, line: Int) -> String {
        let timestamp = dateFormatter.string(from: Date())
        let fileName = (file as NSString).lastPathComponent
        
        return "[\(timestamp)] [\(level.rawValue)] [\(category.rawValue)] [\(fileName):\(line) \(function)] \(message)"
    }
    
    private func writeToFile(entry: String, level: LogLevel) {
        let entryWithNewline = entry + "\n"
        
        // Write to main log file
        appendToFile(url: logFileURL, content: entryWithNewline)
        
        // Write to session log file
        appendToFile(url: sessionLogFileURL, content: entryWithNewline)
        
        // Write errors to error log file
        if level == .error || level == .critical {
            appendToFile(url: errorLogFileURL, content: entryWithNewline)
        }
        
        // Rotate log files if they get too large
        rotateLogFileIfNeeded(url: logFileURL)
    }
    
    private func writeToSystemLog(entry: String, level: LogLevel, category: Category) {
        os_log("%{public}@", log: category.osLog, type: level.osLogType, entry)
    }
    
    private func appendToFile(url: URL, content: String) {
        guard let data = content.data(using: .utf8) else { return }
        
        if fileManager.fileExists(atPath: url.path) {
            if let fileHandle = try? FileHandle(forWritingTo: url) {
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
                fileHandle.closeFile()
            }
        } else {
            try? data.write(to: url)
        }
    }
    
    private func rotateLogFileIfNeeded(url: URL) {
        guard let attributes = try? fileManager.attributesOfItem(atPath: url.path),
              let fileSize = attributes[.size] as? Int64,
              fileSize > maxLogFileSize else {
            return
        }
        
        // Rotate log files
        let baseURL = url.deletingPathExtension()
        let pathExtension = url.pathExtension
        
        // Move existing rotated files
        for i in (1..<maxLogFiles).reversed() {
            let currentURL = baseURL.appendingPathExtension("\(i).\(pathExtension)")
            let nextURL = baseURL.appendingPathExtension("\(i+1).\(pathExtension)")
            
            if fileManager.fileExists(atPath: currentURL.path) {
                try? fileManager.moveItem(at: currentURL, to: nextURL)
            }
        }
        
        // Move current log file to .1
        let rotatedURL = baseURL.appendingPathExtension("1.\(pathExtension)")
        try? fileManager.moveItem(at: url, to: rotatedURL)
    }
    
    private func cleanupOldLogFiles() {
        guard let logDirectory = logFileURL.deletingLastPathComponent().path as String? else { return }
        
        do {
            let files = try fileManager.contentsOfDirectory(atPath: logDirectory)
            let logFiles = files.filter { $0.hasSuffix(".log") }
            
            // Sort by modification date and keep only recent files
            let sortedFiles = logFiles.compactMap { fileName -> (String, Date)? in
                let filePath = (logDirectory as NSString).appendingPathComponent(fileName)
                guard let attributes = try? fileManager.attributesOfItem(atPath: filePath),
                      let modificationDate = attributes[.modificationDate] as? Date else {
                    return nil
                }
                return (filePath, modificationDate)
            }.sorted { $0.1 > $1.1 }
            
            // Remove old files (keep only 10 most recent)
            if sortedFiles.count > 10 {
                for (filePath, _) in sortedFiles.dropFirst(10) {
                    try? fileManager.removeItem(atPath: filePath)
                }
            }
        } catch {
            // Ignore cleanup errors
        }
    }
    
    private func formatError(_ error: Error, context: String) -> String {
        var errorMessage = "ERROR"
        
        if !context.isEmpty {
            errorMessage += " [\(context)]"
        }
        
        errorMessage += ": \(error.localizedDescription)"
        
        // Add more detailed error information if available
        if let nsError = error as NSError? {
            errorMessage += "\nDomain: \(nsError.domain)"
            errorMessage += "\nCode: \(nsError.code)"
            
            if !nsError.userInfo.isEmpty {
                errorMessage += "\nUserInfo: \(nsError.userInfo)"
            }
        }
        
        // Add error type information
        errorMessage += "\nError Type: \(type(of: error))"
        
        return errorMessage
    }
    
    // MARK: - Public Utility Methods
    
    /// Get the current log file path for sharing/debugging
    func getLogFilePath() -> String {
        return logFileURL.path
    }
    
    /// Get the current session log file path
    func getSessionLogFilePath() -> String {
        return sessionLogFileURL.path
    }
    
    /// Get the error log file path
    func getErrorLogFilePath() -> String {
        return errorLogFileURL.path
    }
    
    /// Clear all log files
    func clearLogs() {
        logQueue.async {
            try? self.fileManager.removeItem(at: self.logFileURL)
            try? self.fileManager.removeItem(at: self.sessionLogFileURL)
            try? self.fileManager.removeItem(at: self.errorLogFileURL)
            
            self.initializeLogFiles()
        }
    }
    
    /// Export logs to a specific directory
    func exportLogs(to directory: URL) throws {
        let logDirectory = logFileURL.deletingLastPathComponent()
        let files = try fileManager.contentsOfDirectory(at: logDirectory, includingPropertiesForKeys: nil)
        
        for file in files where file.pathExtension == "log" {
            let destinationURL = directory.appendingPathComponent(file.lastPathComponent)
            try fileManager.copyItem(at: file, to: destinationURL)
        }
    }
}

// MARK: - Helper Extensions

extension ProcessInfo {
    var machineHardwareName: String {
        var size: Int = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var machine = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &machine, &size, nil, 0)
        return String(cString: machine)
    }
}

extension String {
    static func *(left: String, right: Int) -> String {
        return String(repeating: left, count: right)
    }
}
