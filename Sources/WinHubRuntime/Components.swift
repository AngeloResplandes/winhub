import Foundation

/// An optional add-on (DXVK, winetricks…) downloaded on demand and checked by SHA-256.
public struct ComponentManifest: Codable, Sendable, Identifiable, Equatable {
    public enum Kind: String, Codable, Sendable {
        /// A `.tar.*` archive, unpacked into the component folder.
        case archive
        /// A single file (e.g. a script), saved as `fileName` and made executable.
        case executable
    }

    public var id: String
    public var name: String
    public var version: String
    public var kind: Kind
    public var url: URL
    public var sha256: String
    public var size: Int64
    public var license: String
    public var sourceURL: URL
    /// For `.archive`: folder inside the archive with the payload. For `.executable`: the file name.
    public var path: String

    public init(id: String, name: String, version: String, kind: Kind, url: URL, sha256: String, size: Int64,
                license: String, sourceURL: URL, path: String) {
        self.id = id
        self.name = name
        self.version = version
        self.kind = kind
        self.url = url
        self.sha256 = sha256.lowercased()
        self.size = size
        self.license = license
        self.sourceURL = sourceURL
        self.path = path
    }

    public static func loadAll(from url: URL) throws -> [ComponentManifest] {
        try JSONDecoder().decode([ComponentManifest].self, from: Data(contentsOf: url))
    }
}

public struct InstalledComponent: Sendable, Equatable {
    public var manifest: ComponentManifest
    public var root: URL
    /// The payload: the archive's `path` folder, or the executable file.
    public var payload: URL { root.appending(path: manifest.path) }
}

/// Downloads and unpacks components into `root/<id>/`.
public struct ComponentManager: Sendable {
    public let root: URL

    public init(root: URL) {
        self.root = root
    }

    public static var defaultRoot: URL {
        URL.applicationSupportDirectory.appending(path: "WinHub/Components", directoryHint: .isDirectory)
    }

    private static let markerName = ".winhub-component.json"

    public func installed(_ manifest: ComponentManifest) -> InstalledComponent? {
        let dir = root.appending(path: manifest.id, directoryHint: .isDirectory)
        guard let data = try? Data(contentsOf: dir.appending(path: Self.markerName)),
              let recorded = try? JSONDecoder().decode(ComponentManifest.self, from: data),
              recorded.sha256 == manifest.sha256 else { return nil }
        let component = InstalledComponent(manifest: manifest, root: dir)
        return FileManager.default.fileExists(atPath: component.payload.path) ? component : nil
    }

    public func install(_ manifest: ComponentManifest) async throws -> InstalledComponent {
        if let existing = installed(manifest) { return existing }
        let (download, _) = try await URLSession.shared.download(from: manifest.url)
        defer { try? FileManager.default.removeItem(at: download) }
        return try installFile(at: download, manifest: manifest)
    }

    /// Verifies and installs a file that is already on disk.
    public func installFile(at file: URL, manifest: ComponentManifest) throws -> InstalledComponent {
        let actual = try RuntimeManager.sha256(of: file)
        guard actual == manifest.sha256 else {
            throw RuntimeError.checksumMismatch(expected: manifest.sha256, actual: actual)
        }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let staging = root.appending(path: ".staging-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: staging) }

        switch manifest.kind {
        case .archive:
            let result = try ProcessRunner.run(URL(fileURLWithPath: "/usr/bin/tar"),
                                               arguments: ["-xf", file.path, "-C", staging.path])
            guard result.status == 0 else { throw RuntimeError.extractionFailed(status: result.status, output: result.output) }
        case .executable:
            let target = staging.appending(path: manifest.path)
            try FileManager.default.copyItem(at: file, to: target)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: target.path)
        }

        let staged = InstalledComponent(manifest: manifest, root: staging)
        guard FileManager.default.fileExists(atPath: staged.payload.path) else { throw RuntimeError.missingBinary(staged.payload) }

        let destination = root.appending(path: manifest.id, directoryHint: .isDirectory)
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: staging, to: destination)
        try JSONEncoder().encode(manifest).write(to: destination.appending(path: Self.markerName))
        return InstalledComponent(manifest: manifest, root: destination)
    }
}

/// Direct3D implementation used by a bottle.
public enum GraphicsBackend: String, Codable, Sendable, CaseIterable {
    /// Wine's own Direct3D (OpenGL/Vulkan). Works everywhere.
    case wined3d
    /// DXVK-macOS: Direct3D 10/11 over Vulkan (MoltenVK). Often faster in games.
    case dxvk

    public var title: String {
        switch self {
        case .wined3d: "Wine (padrão)"
        case .dxvk: "DXVK (Direct3D 10/11 via Vulkan)"
        }
    }

    /// DLLs DXVK-macOS replaces.
    static let dxvkDLLs = ["d3d10core", "d3d11"]
}

extension WineLauncher {
    /// Switches the bottle's Direct3D. For DXVK the DLLs are copied into the
    /// prefix and loaded "native, then builtin"; Wine's own DLLs are forced back otherwise.
    public func applyGraphics(_ backend: GraphicsBackend, to bottle: Bottle, dxvk: InstalledComponent?) throws -> Bottle {
        var updated = bottle
        switch backend {
        case .wined3d:
            for dll in GraphicsBackend.dxvkDLLs { updated.dllOverrides[dll] = "b" }
        case .dxvk:
            guard let dxvk else { throw RuntimeError.missingBinary(URL(fileURLWithPath: "dxvk")) }
            let windows = bottle.driveC.appending(path: "windows", directoryHint: .isDirectory)
            for (arch, folder) in [("x64", "system32"), ("x32", "syswow64")] {
                let source = dxvk.payload.appending(path: arch, directoryHint: .isDirectory)
                let target = windows.appending(path: folder, directoryHint: .isDirectory)
                guard FileManager.default.fileExists(atPath: target.path) else { continue }
                for dll in GraphicsBackend.dxvkDLLs {
                    let file = source.appending(path: "\(dll).dll")
                    guard FileManager.default.fileExists(atPath: file.path) else { continue }
                    let destination = target.appending(path: "\(dll).dll")
                    try? FileManager.default.removeItem(at: destination)
                    try FileManager.default.copyItem(at: file, to: destination)
                }
            }
            for dll in GraphicsBackend.dxvkDLLs { updated.dllOverrides[dll] = "n,b" }
        }
        updated.graphics = backend
        return updated
    }

    /// Runs winetricks verbs (e.g. `vcrun2022`) unattended in the bottle.
    public func runWinetricks(_ verbs: [String], in bottle: Bottle, winetricks: InstalledComponent) async throws {
        var env = environment(for: bottle)
        env["WINE"] = runtime.wine.path
        env["WINESERVER"] = runtime.wineserver.path
        env["WINETRICKS_LATEST_VERSION_CHECK"] = "disabled"
        let log = logURL(bottle, "winetricks")
        let status = try await ProcessRunner.run(URL(fileURLWithPath: "/bin/sh"),
                                                 arguments: [winetricks.payload.path, "-q", "--unattended"] + verbs,
                                                 environment: env, log: log)
        guard status == 0 else {
            throw WineLauncherError.failed(step: "winetricks \(verbs.joined(separator: " "))", status: status, log: log)
        }
    }
}
