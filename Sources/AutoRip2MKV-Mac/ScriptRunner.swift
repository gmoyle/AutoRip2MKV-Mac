import Foundation

final class ScriptRunner {
    static let shared = ScriptRunner()

    enum ScriptHook: String {
        case preProcessing = "pre_processing"
        case postProcessing = "post_processing"
    }

    struct ScriptExecution {
        let executablePath: String
        let arguments: [String]
    }

    private init() {}

    func runHook(
        _ hook: ScriptHook,
        job: ConversionQueue.ConversionJob,
        outputFiles: [String] = [],
        error: Error? = nil
    ) {
        guard let scriptPath = scriptPath(for: hook) else { return }
        guard let execution = resolveExecution(for: scriptPath) else {
            Logger.shared.log("Script hook skipped (not executable): \(scriptPath)", level: .warning, category: .general)
            return
        }

        let environment = buildEnvironment(hook: hook, job: job, outputFiles: outputFiles, error: error)

        DispatchQueue.global(qos: .utility).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: execution.executablePath)
            process.arguments = execution.arguments + outputFiles
            process.environment = environment
            process.currentDirectoryURL = URL(fileURLWithPath: job.outputDirectory)

            do {
                try process.run()
                process.waitUntilExit()
                Logger.shared.log("Script hook completed: \(hook.rawValue) for job \(job.id)", level: .info, category: .general)
            } catch {
                Logger.shared.logError(error, context: "Script hook failed: \(hook.rawValue) for job \(job.id)")
            }
        }
    }

    func buildEnvironment(
        hook: ScriptHook,
        job: ConversionQueue.ConversionJob,
        outputFiles: [String],
        error: Error?
    ) -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        env["AUTORIP_HOOK"] = hook.rawValue
        env["AUTORIP_JOB_ID"] = job.id.uuidString
        env["AUTORIP_MEDIA_TYPE"] = job.mediaType.folderName
        env["AUTORIP_SOURCE_PATH"] = job.sourcePath
        env["AUTORIP_OUTPUT_DIR"] = job.outputDirectory
        env["AUTORIP_DISC_TITLE"] = job.discTitle
        env["AUTORIP_PRIORITY"] = job.priority.description
        env["AUTORIP_STATUS"] = error == nil ? "success" : "failed"
        env["AUTORIP_OUTPUT_COUNT"] = String(outputFiles.count)
        env["AUTORIP_OUTPUT_FILES"] = outputFiles.joined(separator: ";")

        if let startTime = job.startTime {
            env["AUTORIP_START_TIME"] = iso8601String(from: startTime)
        }
        if let endTime = job.endTime {
            env["AUTORIP_END_TIME"] = iso8601String(from: endTime)
        }
        if let error = error {
            env["AUTORIP_ERROR"] = error.localizedDescription
        }

        return env
    }

    func resolveExecution(for scriptPath: String) -> ScriptExecution? {
        let ext = URL(fileURLWithPath: scriptPath).pathExtension.lowercased()

        switch ext {
        case "py":
            return ScriptExecution(executablePath: "/usr/bin/env", arguments: ["python3", scriptPath])
        case "rb":
            return ScriptExecution(executablePath: "/usr/bin/env", arguments: ["ruby", scriptPath])
        case "js":
            return ScriptExecution(executablePath: "/usr/bin/env", arguments: ["node", scriptPath])
        case "sh":
            return ScriptExecution(executablePath: "/bin/bash", arguments: [scriptPath])
        default:
            if FileManager.default.isExecutableFile(atPath: scriptPath) {
                return ScriptExecution(executablePath: scriptPath, arguments: [])
            }
            return nil
        }
    }

    private func scriptPath(for hook: ScriptHook) -> String? {
        let settings = SettingsManager.shared
        switch hook {
        case .preProcessing:
            return settings.preProcessingScript?.isEmpty == false ? settings.preProcessingScript : nil
        case .postProcessing:
            return settings.postProcessingScript?.isEmpty == false ? settings.postProcessingScript : nil
        }
    }

    private func iso8601String(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}
