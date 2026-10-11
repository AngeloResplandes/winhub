import Foundation

/// A Wine build WinHub can download. Nothing here is bundled: the archive is
/// fetched from `url` on the user's request and must match `sha256`.
public struct RuntimeManifest: Codable, Sendable, Identifiable, Equatable {
    public var id: String
    public var name: String
    public var version: String
    public var url: URL
    public var sha256: String
    public var size: Int64
    public var license: String
    public var sourceURL: URL
    /// Path of the folder holding `wine` and `wineserver`, relative to the extracted archive.
    public var binPath: String

    public init(id: String, name: String, version: String, url: URL, sha256: String, size: Int64,
                license: String, sourceURL: URL, binPath: String) {
        self.id = id
        self.name = name
        self.version = version
        self.url = url
        self.sha256 = sha256.lowercased()
        self.size = size
        self.license = license
        self.sourceURL = sourceURL
        self.binPath = binPath
    }

    public static func loadAll(from url: URL) throws -> [RuntimeManifest] {
        try JSONDecoder().decode([RuntimeManifest].self, from: Data(contentsOf: url))
    }
}

/// A runtime unpacked on disk.
public struct InstalledRuntime: Sendable, Equatable {
    public var manifest: RuntimeManifest
    public var root: URL

    public var binDirectory: URL { root.appending(path: manifest.binPath, directoryHint: .isDirectory) }
    public var wine: URL { binDirectory.appending(path: "wine") }
    public var wineserver: URL { binDirectory.appending(path: "wineserver") }

    public init(manifest: RuntimeManifest, root: URL) {
        self.manifest = manifest
        self.root = root
    }
}
