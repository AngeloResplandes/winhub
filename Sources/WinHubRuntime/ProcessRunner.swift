import Foundation

/// Small helpers around `Process`.
enum ProcessRunner {
    struct Result: Sendable {
        var status: Int32
        var output: String
    }

    /// Runs a short command synchronously and captures its combined output.
    static func run(_ executable: URL, arguments: [String], environment: [String: String]? = nil) throws -> Result {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        if let environment { process.environment = environment }
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return Result(status: process.terminationStatus, output: String(decoding: data, as: UTF8.self))
    }

    /// Runs a command, appending its output to `log`, and returns its exit status.
    static func run(_ executable: URL, arguments: [String], environment: [String: String],
                    log: URL) async throws -> Int32 {
        try FileManager.default.createDirectory(at: log.deletingLastPathComponent(), withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: log.path) {
            FileManager.default.createFile(atPath: log.path, contents: nil)
        }
        let handle = try FileHandle(forWritingTo: log)
        try handle.seekToEnd()

        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.environment = environment
        process.standardOutput = handle
        process.standardError = handle

        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { finished in
                try? handle.close()
                continuation.resume(returning: finished.terminationStatus)
            }
            do {
                try process.run()
            } catch {
                process.terminationHandler = nil
                try? handle.close()
                continuation.resume(throwing: error)
            }
        }
    }
}
