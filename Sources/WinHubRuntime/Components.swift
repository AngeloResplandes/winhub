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
    /// The engine picks the best one that runs here (D3DMetal, then DXMT, then Wine's).
    /// Only with engines that pick the Direct3D themselves.
    case auto
    /// Wine's own Direct3D (OpenGL/Vulkan). Works everywhere.
    case wined3d
    /// DXVK-macOS: Direct3D 10/11 over Vulkan (MoltenVK). Often faster in games.
    case dxvk
    /// DXMT: Direct3D 10/11 straight over Metal. Needs a runtime built for it.
    case dxmt
    /// Apple's D3DMetal (Direct3D 11/12), only when the user installed the Game Porting Toolkit.
    case d3dmetal

    public var title: String {
        switch self {
        case .auto: String(localized: "Automático (o melhor que funcionar)")
        case .wined3d: String(localized: "Wine (padrão)")
        case .dxvk: "DXVK (Direct3D 10/11 via Vulkan)"
        case .dxmt: "DXMT (Direct3D 10/11 via Metal)"
        case .d3dmetal: String(localized: "D3DMetal (Direct3D 11/12, da Apple)")
        }
    }

    /// Short name for buttons and lists.
    public var shortTitle: String {
        switch self {
        case .auto: String(localized: "Automático")
        case .wined3d: "Wine"
        case .dxvk: "DXVK"
        case .dxmt: "DXMT"
        case .d3dmetal: "D3DMetal"
        }
    }

    /// Only engines that pick the Direct3D themselves offer it.
    public var needsDispatchingEngine: Bool { self == .auto || self == .d3dmetal }

    /// DLLs DXVK-macOS replaces.
    static let dxvkDLLs = ["d3d10core", "d3d11"]
    /// DLLs DXMT replaces; `winemetal` is its bridge to the Mac side and is only copied.
    static let dxmtDLLs = ["d3d10core", "d3d11", "dxgi"]
    static let dxmtFiles = dxmtDLLs + ["winemetal"]
    /// Every DLL any backend puts in place of Wine's.
    static let replacedDLLs = ["d3d10core", "d3d11", "dxgi"]

    /// DLLs to copy and to load "native, then builtin"; empty for Wine's own Direct3D and for the
    /// backends only an engine that picks the Direct3D can use.
    var files: [String] {
        switch self {
        case .auto, .wined3d, .d3dmetal: []
        case .dxvk: Self.dxvkDLLs
        case .dxmt: Self.dxmtFiles
        }
    }

    var overriddenDLLs: [String] {
        switch self {
        case .auto, .wined3d, .d3dmetal: []
        case .dxvk: Self.dxvkDLLs
        case .dxmt: Self.dxmtDLLs
        }
    }
}

/// Machine type of a Windows executable, read from its PE header.
public enum PEArchitecture: Sendable {
    case x64, x86

    /// Folder name used by DXVK and DXMT for this architecture's DLLs.
    var dllFolder: String { self == .x64 ? "x64" : "x32" }

    public static func of(_ file: URL) -> PEArchitecture? {
        guard let handle = try? FileHandle(forReadingFrom: file) else { return nil }
        defer { try? handle.close() }
        guard let header = try? handle.read(upToCount: 4096), header.count >= 0x40,
              header[0] == 0x4D, header[1] == 0x5A else { return nil }
        let peOffset = Int(header[0x3C]) | Int(header[0x3D]) << 8 | Int(header[0x3E]) << 16 | Int(header[0x3F]) << 24
        guard peOffset + 6 <= header.count,
              header[peOffset] == 0x50, header[peOffset + 1] == 0x45,
              header[peOffset + 2] == 0, header[peOffset + 3] == 0 else { return nil }
        switch UInt16(header[peOffset + 4]) | UInt16(header[peOffset + 5]) << 8 {
        case 0x8664: return .x64
        case 0x014C: return .x86
        default: return nil
        }
    }
}

public enum GraphicsError: Error, LocalizedError, Equatable {
    case programNotFound(String)
    case unknownArchitecture(String)
    case programShipsDLL(String)
    case unsupported(GraphicsBackend)

    public var errorDescription: String? {
        switch self {
        case .programNotFound(let path): String(localized: "O programa \(path) não foi encontrado na garrafa.")
        case .unknownArchitecture(let name): String(localized: "Não foi possível saber se \(name) é de 32 ou 64 bits.")
        case .programShipsDLL(let dll): String(localized: "O programa já traz o próprio \(dll).dll; o WinHub não vai substituí-lo.")
        case .unsupported(let backend): String(localized: "O motor instalado não oferece \(backend.shortTitle).")
        }
    }
}

extension WineLauncher {
    /// Switches the bottle's Direct3D. For DXVK and DXMT the DLLs are copied into the
    /// prefix and loaded "native, then builtin"; for Wine's own, its DLLs are put back.
    /// Engines that pick the Direct3D themselves only need the setting (and Wine's DLLs back).
    public func applyGraphics(_ backend: GraphicsBackend, to bottle: Bottle, dxvk: InstalledComponent?) throws -> Bottle {
        if runtime.dispatchesGraphics { return removeCopiedGraphics(from: bottle, keeping: backend) }
        var updated = bottle
        let source = try graphicsSource(backend, dxvk: dxvk)
        restoreWineDLLs(GraphicsBackend.replacedDLLs.filter { !backend.overriddenDLLs.contains($0) }, in: &updated)
        if let source {
            for (arch, folder) in [(PEArchitecture.x64, "system32"), (.x86, "syswow64")] {
                let target = bottle.driveC.appending(path: "windows/\(folder)", directoryHint: .isDirectory)
                guard FileManager.default.fileExists(atPath: target.path) else { continue }
                try copyDLLs(backend.files, from: source.appending(path: arch.dllFolder, directoryHint: .isDirectory),
                             into: target)
            }
            for dll in backend.overriddenDLLs { updated.dllOverrides[dll] = "n,b" }
        }
        updated.graphics = backend
        return updated
    }

    /// Folder with the backend's `x64/` and `x32/` DLLs; `nil` for Wine's own Direct3D.
    private func graphicsSource(_ backend: GraphicsBackend, dxvk: InstalledComponent?) throws -> URL? {
        switch backend {
        case .auto, .d3dmetal:
            throw GraphicsError.unsupported(backend)
        case .wined3d:
            return nil
        case .dxvk:
            guard let dxvk else { throw RuntimeError.missingBinary(URL(fileURLWithPath: "dxvk")) }
            return dxvk.payload
        case .dxmt:
            let source = runtime.dxmtDirectory
            guard runtime.manifest.supports(.dxmt), FileManager.default.fileExists(atPath: source.path) else {
                throw RuntimeError.missingBinary(source)
            }
            return source
        }
    }

    /// Puts Wine's own DLLs back into the prefix and drops their overrides, so per-program
    /// settings in the registry are not shadowed by `WINEDLLOVERRIDES`. Runtimes without
    /// the DLLs on disk get "builtin" overrides instead, as before.
    private func restoreWineDLLs(_ dlls: [String], in bottle: inout Bottle) {
        for dll in dlls {
            var restored = true
            for (folder, wineFolder) in [("system32", "x86_64-windows"), ("syswow64", "i386-windows")] {
                let target = bottle.driveC.appending(path: "windows/\(folder)", directoryHint: .isDirectory)
                guard FileManager.default.fileExists(atPath: target.path) else { continue }
                let original = runtime.wineDirectory.appending(path: "lib/wine/\(wineFolder)/\(dll).dll")
                guard FileManager.default.fileExists(atPath: original.path),
                      (try? copyDLLs([dll], from: original.deletingLastPathComponent(), into: target)) != nil else {
                    restored = false
                    continue
                }
            }
            if restored {
                bottle.dllOverrides[dll] = nil
            } else if bottle.dllOverrides[dll] != nil || GraphicsBackend.dxvkDLLs.contains(dll) {
                bottle.dllOverrides[dll] = "b"
            }
        }
    }

    /// Copies `<source>/<dll>.dll` into `target` for each DLL that exists in the source.
    private func copyDLLs(_ dlls: [String], from source: URL, into target: URL) throws {
        for dll in dlls {
            let file = source.appending(path: "\(dll).dll")
            guard FileManager.default.fileExists(atPath: file.path) else { continue }
            let destination = target.appending(path: "\(dll).dll")
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.copyItem(at: file, to: destination)
        }
    }

    /// Registry key with one program's DLL overrides; it wins over the prefix-wide ones.
    static func appDefaultsKey(for program: String) -> String {
        #"HKCU\Software\Wine\AppDefaults\"# + program + #"\DllOverrides"#
    }

    /// Gives one program its own Direct3D (`nil`: the bottle's). The DLLs go next to the
    /// `.exe` and the program gets "native, then builtin" overrides in the registry, so the
    /// rest of the bottle (the Steam client, say) keeps the bottle's setting. Engines that pick the
    /// Direct3D themselves get a rule in the bottle's `CompatRules` instead.
    public func applyProgramGraphics(_ backend: GraphicsBackend?, program windowsPath: String, in bottle: Bottle,
                                     dxvk: InstalledComponent?) async throws -> Bottle {
        guard let exe = bottle.unixPath(forWindowsPath: windowsPath),
              FileManager.default.fileExists(atPath: exe.path) else {
            throw GraphicsError.programNotFound(windowsPath)
        }
        if runtime.dispatchesGraphics {
            var updated = try await removeCopiedProgramGraphics(windowsPath, in: bottle)
            try CompatRules.setProgramBackend(backend, program: windowsPath, in: updated)
            updated.programGraphics[windowsPath] = backend == .auto ? nil : backend
            return updated
        }
        guard let arch = PEArchitecture.of(exe) else { throw GraphicsError.unknownArchitecture(exe.lastPathComponent) }
        let folder = exe.deletingLastPathComponent()
        let source = try backend.flatMap { try graphicsSource($0, dxvk: dxvk) }

        var updated = bottle
        // `WINEDLLOVERRIDES` beats the registry; a bottle forcing Wine's DLLs would hide these.
        if updated.graphics == .wined3d { restoreWineDLLs(GraphicsBackend.replacedDLLs, in: &updated) }

        let ours = knownGraphicsDLLs(arch: arch, dxvk: dxvk)
        let wanted = backend?.files ?? []
        for dll in GraphicsBackend.replacedDLLs + ["winemetal"] {
            let file = folder.appending(path: "\(dll).dll")
            guard let data = try? Data(contentsOf: file) else { continue }
            if ours.contains(data) {
                try FileManager.default.removeItem(at: file)
            } else if wanted.contains(dll) {
                throw GraphicsError.programShipsDLL(dll)
            }
        }

        let key = Self.appDefaultsKey(for: exe.lastPathComponent)
        _ = try await run(updated, ["reg", "delete", key, "/f"], logName: "reg")
        if let backend, let source {
            try copyDLLs(backend.files, from: source.appending(path: arch.dllFolder, directoryHint: .isDirectory), into: folder)
            for dll in backend.overriddenDLLs {
                let status = try await run(updated, ["reg", "add", key, "/v", dll, "/d", "native,builtin", "/f"], logName: "reg")
                guard status == 0 else {
                    throw WineLauncherError.failed(step: String(localized: "Registrar \(dll) para \(exe.lastPathComponent)"), status: status,
                                                   log: logURL(updated, "reg"))
                }
            }
        }
        updated.programGraphics[windowsPath] = backend
        return updated
    }

    /// Settles a bottle set up for an engine that had DLLs copied once the installed engine picks the
    /// Direct3D itself: Wine's DLLs go back, the copied ones and their overrides go away, and programs
    /// with their own Direct3D get rules instead. Returns the bottle when something changed.
    public func migrateToDispatchedGraphics(_ bottle: Bottle) async throws -> Bottle? {
        guard runtime.dispatchesGraphics else { return nil }
        var updated = bottle
        if needsCleanup(bottle) { updated = removeCopiedGraphics(from: updated, keeping: updated.graphics) }
        for (program, backend) in bottle.programGraphics where CompatRules.programBackend(program, in: bottle) != backend {
            updated = try await removeCopiedProgramGraphics(program, in: updated)
            try CompatRules.setProgramBackend(backend, program: program, in: updated)
        }
        return updated == bottle ? nil : updated
    }

    /// DXVK/DXMT were copied into the prefix for an earlier engine, or the prefix does not have the
    /// engine's own `winemetal.dll` (Wine finds that builtin only through its file in system32, which
    /// a prefix made by an older engine lacks or holds a copied DXMT build of).
    private func needsCleanup(_ bottle: Bottle) -> Bool {
        GraphicsBackend.replacedDLLs.contains { bottle.dllOverrides[$0] == "n,b" } ||
            Self.prefixFolders.contains { folder, wineFolder in
                let prefixFolder = bottle.driveC.appending(path: "windows/\(folder)", directoryHint: .isDirectory)
                let engine = runtime.wineDirectory.appending(path: "lib/wine/\(wineFolder)/winemetal.dll")
                guard FileManager.default.fileExists(atPath: prefixFolder.path),
                      FileManager.default.fileExists(atPath: engine.path) else { return false }
                return !FileManager.default.contentsEqual(atPath: prefixFolder.appending(path: "winemetal.dll").path,
                                                         andPath: engine.path)
            }
    }

    private static let prefixFolders = [("system32", "x86_64-windows"), ("syswow64", "i386-windows")]

    /// Puts the engine's Direct3D DLLs and DXMT bridge back into the prefix, drops their overrides
    /// and records `backend`.
    private func removeCopiedGraphics(from bottle: Bottle, keeping backend: GraphicsBackend) -> Bottle {
        var updated = bottle
        restoreWineDLLs(GraphicsBackend.replacedDLLs + ["winemetal"], in: &updated)
        updated.graphics = backend
        return updated
    }

    /// Removes the DLLs WinHub copied next to a program for an earlier engine and their registry overrides.
    /// A choice that already has a rule was made with this engine, so nothing was copied for it.
    private func removeCopiedProgramGraphics(_ windowsPath: String, in bottle: Bottle) async throws -> Bottle {
        guard let previous = bottle.programGraphics[windowsPath], !previous.files.isEmpty,
              CompatRules.programBackend(windowsPath, in: bottle) == nil,
              let folder = bottle.unixPath(forWindowsPath: windowsPath)?.deletingLastPathComponent() else { return bottle }
        // Only copies are here: WinHub refused to replace DLLs a program brings itself.
        for dll in previous.files { try? FileManager.default.removeItem(at: folder.appending(path: "\(dll).dll")) }
        let program = windowsPath.split(whereSeparator: { $0 == "\\" || $0 == "/" }).last.map(String.init) ?? windowsPath
        _ = try await run(bottle, ["reg", "delete", Self.appDefaultsKey(for: program), "/f"], logName: "reg")
        return bottle
    }

    /// Contents of every DLL the WinHub may have put next to a program, to recognize them later.
    private func knownGraphicsDLLs(arch: PEArchitecture, dxvk: InstalledComponent?) -> Set<Data> {
        var sources = [runtime.dxmtDirectory]
        if let dxvk { sources.append(dxvk.payload) }
        var known = Set<Data>()
        for source in sources {
            for dll in GraphicsBackend.replacedDLLs + ["winemetal"] {
                let file = source.appending(path: "\(arch.dllFolder)/\(dll).dll")
                if let data = try? Data(contentsOf: file) { known.insert(data) }
            }
        }
        return known
    }

    /// Environment for winetricks: the bottle's, plus the Wine binaries and,
    /// when installed, the folder with `cabextract` (needed by some verbs).
    public func winetricksEnvironment(for bottle: Bottle, cabextract: InstalledComponent?) -> [String: String] {
        var env = environment(for: bottle)
        env["WINE"] = runtime.wine.path
        env["WINESERVER"] = runtime.wineserver.path
        env["WINETRICKS_LATEST_VERSION_CHECK"] = "disabled"
        if let cabextract, let path = env["PATH"] {
            env["PATH"] = "\(cabextract.payload.path):\(path)"
        }
        return env
    }

    /// Runs winetricks verbs (e.g. `vcrun2022`) unattended in the bottle.
    public func runWinetricks(_ verbs: [String], in bottle: Bottle, winetricks: InstalledComponent,
                              cabextract: InstalledComponent? = nil) async throws {
        let env = winetricksEnvironment(for: bottle, cabextract: cabextract)
        let log = logURL(bottle, "winetricks")
        let status = try await ProcessRunner.run(URL(fileURLWithPath: "/bin/sh"),
                                                 arguments: [winetricks.payload.path, "-q", "--unattended"] + verbs,
                                                 environment: env, log: log)
        guard status == 0 else {
            throw WineLauncherError.failed(step: "winetricks \(verbs.joined(separator: " "))", status: status, log: log)
        }
    }
}
