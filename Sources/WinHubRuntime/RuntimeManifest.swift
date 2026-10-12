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
    /// Optional abilities of this build, e.g. `"dxmt"` (D3D11 over Metal) or `"msync"`.
    public var features: [String]
    /// Files unpacked over the Wine folder (the parent of `binPath`) after the main archive,
    /// e.g. WinHub's engine additions on top of the official WineHQ build.
    public var overlay: Overlay?

    public struct Overlay: Codable, Sendable, Equatable {
        public var url: URL
        public var sha256: String
        public var size: Int64
        /// Folders of the main archive's Wine folder removed before the overlay is unpacked, e.g.
        /// `["bin", "lib/wine"]` for an engine that brings its own Wine.
        public var replace: [String]

        public init(url: URL, sha256: String, size: Int64, replace: [String] = []) {
            self.url = url
            self.sha256 = sha256.lowercased()
            self.size = size
            self.replace = replace
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.init(url: try c.decode(URL.self, forKey: .url), sha256: try c.decode(String.self, forKey: .sha256),
                      size: try c.decode(Int64.self, forKey: .size),
                      replace: try c.decodeIfPresent([String].self, forKey: .replace) ?? [])
        }
    }

    public init(id: String, name: String, version: String, url: URL, sha256: String, size: Int64,
                license: String, sourceURL: URL, binPath: String, features: [String] = [], overlay: Overlay? = nil) {
        self.id = id
        self.name = name
        self.version = version
        self.url = url
        self.sha256 = sha256.lowercased()
        self.size = size
        self.license = license
        self.sourceURL = sourceURL
        self.binPath = binPath
        self.features = features
        self.overlay = overlay
    }

    enum CodingKeys: String, CodingKey {
        case id, name, version, url, sha256, size, license, sourceURL, binPath, features, overlay
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(id: try c.decode(String.self, forKey: .id),
                  name: try c.decode(String.self, forKey: .name),
                  version: try c.decode(String.self, forKey: .version),
                  url: try c.decode(URL.self, forKey: .url),
                  sha256: try c.decode(String.self, forKey: .sha256),
                  size: try c.decode(Int64.self, forKey: .size),
                  license: try c.decode(String.self, forKey: .license),
                  sourceURL: try c.decode(URL.self, forKey: .sourceURL),
                  binPath: try c.decode(String.self, forKey: .binPath),
                  features: try c.decodeIfPresent([String].self, forKey: .features) ?? [],
                  overlay: try c.decodeIfPresent(Overlay.self, forKey: .overlay))
    }

    /// Same files on disk: same id, main archive and overlay.
    public func isSameBuild(as other: RuntimeManifest) -> Bool {
        id == other.id && sha256 == other.sha256 && overlay?.sha256 == other.overlay?.sha256
    }

    /// Bytes to download: the main archive plus the overlay.
    public var downloadSize: Int64 { size + (overlay?.size ?? 0) }

    public func supports(_ feature: Feature) -> Bool { features.contains(feature.rawValue) }

    public enum Feature: String, Sendable {
        /// Ships DXMT and a `winemac.so` exporting the symbols it needs.
        case dxmt
        /// Ships DXVK in `lib/dxvk`.
        case dxvk
        /// Built with the msync patches (`WINEMSYNC=1`).
        case msync
        /// Picks the Direct3D itself (`WINHUB_GRAPHICS_BACKEND`): nothing is copied into bottles.
        case backendDispatch = "backend-dispatch"
        /// Reads compatibility rules (`WINHUB_COMPAT_RULES`, `WINHUB_HOME/compat/compatdb.json`).
        case compatdb
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
    /// The folder holding `bin/` and `lib/`, where the overlay is unpacked.
    public var wineDirectory: URL { binDirectory.deletingLastPathComponent() }
    /// Picks the Direct3D at run time instead of having DLLs copied into bottles.
    public var dispatchesGraphics: Bool { manifest.supports(.backendDispatch) }
    /// DXMT's Direct3D DLLs (`x64/`, `x32/`), copied into bottles that use it. Engines that pick the
    /// Direct3D themselves lay it out like a Wine library folder instead and copy nothing.
    public var dxmtDirectory: URL {
        wineDirectory.appending(path: "lib/dxmt", directoryHint: .isDirectory)
    }

    public init(manifest: RuntimeManifest, root: URL) {
        self.manifest = manifest
        self.root = root
    }
}
