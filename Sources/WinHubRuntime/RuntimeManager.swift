import CryptoKit
import Foundation

public enum RuntimeError: Error, LocalizedError, Equatable {
    case checksumMismatch(expected: String, actual: String)
    case extractionFailed(status: Int32, output: String)
    case missingBinary(URL)
    case rosettaUnavailable

    public var errorDescription: String? {
        switch self {
        case .checksumMismatch(let expected, let actual):
            "O arquivo baixado não confere (SHA-256 esperado \(expected.prefix(12))…, obtido \(actual.prefix(12))…). Nada foi instalado."
        case .extractionFailed(let status, let output):
            "Não foi possível extrair o motor (código \(status)). \(output)"
        case .missingBinary(let url):
            "O motor não contém \(url.lastPathComponent) no local esperado."
        case .rosettaUnavailable:
            "Este Mac precisa do Rosetta 2. Instale com: softwareupdate --install-rosetta --agree-to-license"
        }
    }
}

/// Downloads, verifies and unpacks Wine builds into `root/<id>/`.
public struct RuntimeManager: Sendable {
    public let root: URL

    public init(root: URL) {
        self.root = root
    }

    public static var defaultRoot: URL {
        URL.applicationSupportDirectory.appending(path: "WinHub/Runtimes", directoryHint: .isDirectory)
    }

    private static let markerName = ".winhub-runtime.json"

    public func directory(for id: String) -> URL {
        root.appending(path: id, directoryHint: .isDirectory)
    }

    /// The runtime if it was fully installed (the marker is written last).
    public func installed(_ manifest: RuntimeManifest) -> InstalledRuntime? {
        let dir = directory(for: manifest.id)
        let marker = dir.appending(path: Self.markerName)
        guard let data = try? Data(contentsOf: marker),
              let recorded = try? JSONDecoder().decode(RuntimeManifest.self, from: data),
              recorded.sha256 == manifest.sha256 else { return nil }
        let runtime = InstalledRuntime(manifest: manifest, root: dir)
        return FileManager.default.isExecutableFile(atPath: runtime.wine.path) ? runtime : nil
    }

    /// Downloads `manifest.url`, checks its SHA-256 and unpacks it. Progress is 0…1.
    public func install(_ manifest: RuntimeManifest,
                        progress: @escaping @Sendable (Double) -> Void = { _ in }) async throws -> InstalledRuntime {
        try Self.requireRosetta()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let delegate = DownloadProgressDelegate(expectedSize: manifest.size, onProgress: progress)
        let (download, _) = try await URLSession.shared.download(from: manifest.url, delegate: delegate)
        defer { try? FileManager.default.removeItem(at: download) }
        return try installArchive(at: download, manifest: manifest)
    }

    /// Verifies and unpacks an archive that is already on disk.
    public func installArchive(at archive: URL, manifest: RuntimeManifest) throws -> InstalledRuntime {
        let actual = try Self.sha256(of: archive)
        guard actual == manifest.sha256 else {
            throw RuntimeError.checksumMismatch(expected: manifest.sha256, actual: actual)
        }

        let staging = root.appending(path: ".staging-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: staging) }

        let result = try ProcessRunner.run(URL(fileURLWithPath: "/usr/bin/tar"),
                                           arguments: ["-xf", archive.path, "-C", staging.path])
        guard result.status == 0 else {
            throw RuntimeError.extractionFailed(status: result.status, output: result.output)
        }

        let runtime = InstalledRuntime(manifest: manifest, root: staging)
        guard FileManager.default.isExecutableFile(atPath: runtime.wine.path) else {
            throw RuntimeError.missingBinary(runtime.wine)
        }

        let destination = directory(for: manifest.id)
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: staging, to: destination)
        try JSONEncoder().encode(manifest).write(to: destination.appending(path: Self.markerName))
        return InstalledRuntime(manifest: manifest, root: destination)
    }

    public func remove(_ manifest: RuntimeManifest) throws {
        let dir = directory(for: manifest.id)
        if FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.removeItem(at: dir)
        }
    }

    public static func sha256(of file: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: file)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 4 << 20), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    /// Wine builds for macOS are x86_64, so Apple silicon needs Rosetta 2.
    public static var isRosettaAvailable: Bool {
        #if arch(arm64)
        FileManager.default.fileExists(atPath: "/Library/Apple/usr/libexec/oah/libRosettaRuntime")
        #else
        true
        #endif
    }

    static func requireRosetta() throws {
        guard isRosettaAvailable else { throw RuntimeError.rosettaUnavailable }
    }
}

private final class DownloadProgressDelegate: NSObject, URLSessionDownloadDelegate, Sendable {
    let expectedSize: Int64
    let onProgress: @Sendable (Double) -> Void

    init(expectedSize: Int64, onProgress: @escaping @Sendable (Double) -> Void) {
        self.expectedSize = expectedSize
        self.onProgress = onProgress
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let total = totalBytesExpectedToWrite > 0 ? totalBytesExpectedToWrite : expectedSize
        guard total > 0 else { return }
        onProgress(min(Double(totalBytesWritten) / Double(total), 1))
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {}
}
