import Foundation

/// Downloads installers into a cache folder, optionally checking their SHA-256.
public struct Downloader: Sendable {
    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    public static var defaultDirectory: URL {
        URL.cachesDirectory.appending(path: "WinHub/Downloads", directoryHint: .isDirectory)
    }

    /// Downloads `url` to `directory/fileName`, replacing an older copy.
    public func download(_ url: URL, fileName: String, sha256: String? = nil) async throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let (temporary, response) = try await URLSession.shared.download(from: url)
        defer { try? FileManager.default.removeItem(at: temporary) }
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        if let expected = sha256?.lowercased() {
            let actual = try RuntimeManager.sha256(of: temporary)
            guard actual == expected else { throw RuntimeError.checksumMismatch(expected: expected, actual: actual) }
        }
        let destination = directory.appending(path: fileName)
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: temporary, to: destination)
        return destination
    }
}
