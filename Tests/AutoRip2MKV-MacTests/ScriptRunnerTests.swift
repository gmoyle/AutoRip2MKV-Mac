import XCTest
@testable import AutoRip2MKV_Mac

final class ScriptRunnerTests: XCTestCase {

    func testBuildEnvironmentIncludesJobMetadata() {
        let job = makeJob()
        let outputFiles = ["/tmp/output1.mkv", "/tmp/output2.mkv"]

        let env = ScriptRunner.shared.buildEnvironment(
            hook: .postProcessing,
            job: job,
            outputFiles: outputFiles,
            error: nil
        )

        XCTAssertEqual(env["AUTORIP_HOOK"], "post_processing")
        XCTAssertEqual(env["AUTORIP_JOB_ID"], job.id.uuidString)
        XCTAssertEqual(env["AUTORIP_MEDIA_TYPE"], job.mediaType.folderName)
        XCTAssertEqual(env["AUTORIP_SOURCE_PATH"], job.sourcePath)
        XCTAssertEqual(env["AUTORIP_OUTPUT_DIR"], job.outputDirectory)
        XCTAssertEqual(env["AUTORIP_DISC_TITLE"], job.discTitle)
        XCTAssertEqual(env["AUTORIP_PRIORITY"], job.priority.description)
        XCTAssertEqual(env["AUTORIP_STATUS"], "success")
        XCTAssertEqual(env["AUTORIP_OUTPUT_COUNT"], "2")
        XCTAssertEqual(env["AUTORIP_OUTPUT_FILES"], outputFiles.joined(separator: ";"))
    }

    func testBuildEnvironmentIncludesErrorDetails() {
        let job = makeJob()
        let testError = NSError(domain: "ScriptRunnerTests", code: 42, userInfo: [NSLocalizedDescriptionKey: "Test failure"])

        let env = ScriptRunner.shared.buildEnvironment(
            hook: .postProcessing,
            job: job,
            outputFiles: [],
            error: testError
        )

        XCTAssertEqual(env["AUTORIP_STATUS"], "failed")
        XCTAssertEqual(env["AUTORIP_ERROR"], "Test failure")
    }

    func testResolveExecutionForScriptExtensions() {
        let runner = ScriptRunner.shared

        let python = runner.resolveExecution(for: "/tmp/test.py")
        XCTAssertEqual(python?.executablePath, "/usr/bin/env")
        XCTAssertEqual(python?.arguments, ["python3", "/tmp/test.py"])

        let ruby = runner.resolveExecution(for: "/tmp/test.rb")
        XCTAssertEqual(ruby?.executablePath, "/usr/bin/env")
        XCTAssertEqual(ruby?.arguments, ["ruby", "/tmp/test.rb"])

        let node = runner.resolveExecution(for: "/tmp/test.js")
        XCTAssertEqual(node?.executablePath, "/usr/bin/env")
        XCTAssertEqual(node?.arguments, ["node", "/tmp/test.js"])

        let shell = runner.resolveExecution(for: "/tmp/test.sh")
        XCTAssertEqual(shell?.executablePath, "/bin/bash")
        XCTAssertEqual(shell?.arguments, ["/tmp/test.sh"])
    }

    func testResolveExecutionForExecutableFile() throws {
        let tempDir = NSTemporaryDirectory()
        let filePath = (tempDir as NSString).appendingPathComponent("autorip_script_test")
        let fileURL = URL(fileURLWithPath: filePath)

        try "#!/bin/sh\necho test\n".write(to: fileURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: filePath)

        let execution = ScriptRunner.shared.resolveExecution(for: filePath)
        XCTAssertEqual(execution?.executablePath, filePath)
        XCTAssertEqual(execution?.arguments, [])

        try? FileManager.default.removeItem(atPath: filePath)
    }

    private func makeJob() -> ConversionQueue.ConversionJob {
        let config = MediaRipper.RippingConfiguration(
            outputDirectory: "/tmp",
            selectedTitles: [],
            videoCodec: .h264,
            audioCodec: .aac,
            quality: .high,
            includeSubtitles: true,
            includeChapters: true,
            mediaType: nil,
            batchMode: false
        )

        return ConversionQueue.ConversionJob(
            sourcePath: "/Volumes/TEST_DISC",
            outputDirectory: "/tmp/output",
            configuration: config,
            mediaType: .dvd,
            discTitle: "Test Disc",
            priority: .high
        )
    }
}
