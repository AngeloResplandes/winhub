import Foundation
import Testing
@testable import WinHubRuntime

/// A fresh temporary folder per test.
func makeTempDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appending(path: "winhub-tests-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

/// Builds `archive.tar.xz` containing `Fake.app/bin/wine` and `wineserver` scripts.
func makeFakeRuntimeArchive(in dir: URL) throws -> (archive: URL, manifest: RuntimeManifest) {
    let content = dir.appending(path: "content/Fake.app/bin", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: content, withIntermediateDirectories: true)
    for name in ["wine", "wineserver"] {
        let file = content.appending(path: name)
        try "#!/bin/sh\nexit 0\n".write(to: file, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: file.path)
    }
    let archive = dir.appending(path: "archive.tar.xz")
    let tar = try ProcessRunner.run(URL(fileURLWithPath: "/usr/bin/tar"),
                                    arguments: ["-cJf", archive.path, "-C", dir.appending(path: "content").path, "Fake.app"])
    #expect(tar.status == 0)
    let manifest = RuntimeManifest(id: "fake-1", name: "Fake", version: "1", url: URL(string: "https://example.invalid/a.tar.xz")!,
                                   sha256: try RuntimeManager.sha256(of: archive), size: 1, license: "MIT",
                                   sourceURL: URL(string: "https://example.invalid")!, binPath: "Fake.app/bin")
    return (archive, manifest)
}

@Suite struct RuntimeManagerTests {
    @Test func installsVerifiedArchive() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let (archive, manifest) = try makeFakeRuntimeArchive(in: dir)
        let manager = RuntimeManager(root: dir.appending(path: "runtimes"))

        #expect(manager.installed(manifest) == nil)
        let runtime = try manager.installArchive(at: archive, manifest: manifest)
        #expect(FileManager.default.isExecutableFile(atPath: runtime.wine.path))
        #expect(manager.installed(manifest)?.root == runtime.root)

        try manager.remove(manifest)
        #expect(manager.installed(manifest) == nil)
    }

    @Test func rejectsWrongChecksum() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        var (archive, manifest) = try makeFakeRuntimeArchive(in: dir)
        manifest.sha256 = String(repeating: "0", count: 64)
        let manager = RuntimeManager(root: dir.appending(path: "runtimes"))

        #expect(throws: RuntimeError.self) { try manager.installArchive(at: archive, manifest: manifest) }
        #expect(manager.installed(manifest) == nil)
    }

    @Test func rejectsArchiveWithoutWine() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        var (archive, manifest) = try makeFakeRuntimeArchive(in: dir)
        manifest.binPath = "Other/bin"
        let manager = RuntimeManager(root: dir.appending(path: "runtimes"))
        #expect(throws: RuntimeError.self) { try manager.installArchive(at: archive, manifest: manifest) }
    }

    @Test func installsOverlayOverTheWineFolder() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        var (archive, manifest) = try makeFakeRuntimeArchive(in: dir)
        let content = dir.appending(path: "overlay/lib/dxmt/x64", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: content, withIntermediateDirectories: true)
        try "dxmt".write(to: content.appending(path: "d3d11.dll"), atomically: true, encoding: .utf8)
        let overlayArchive = dir.appending(path: "overlay.tar.xz")
        let tar = try ProcessRunner.run(URL(fileURLWithPath: "/usr/bin/tar"),
                                        arguments: ["-cJf", overlayArchive.path, "-C", dir.appending(path: "overlay").path, "lib"])
        #expect(tar.status == 0)
        manifest.overlay = .init(url: URL(string: "https://example.invalid/o.tar.xz")!,
                                 sha256: try RuntimeManager.sha256(of: overlayArchive), size: 1)
        manifest.features = ["dxmt"]
        let manager = RuntimeManager(root: dir.appending(path: "runtimes"))

        #expect(throws: RuntimeError.self) { try manager.installArchive(at: archive, manifest: manifest) }
        var tampered = manifest
        tampered.overlay?.sha256 = String(repeating: "0", count: 64)
        #expect(throws: RuntimeError.self) {
            try manager.installArchive(at: archive, overlay: overlayArchive, manifest: tampered)
        }

        let runtime = try manager.installArchive(at: archive, overlay: overlayArchive, manifest: manifest)
        // binPath is "Fake.app/bin", so the overlay lands in "Fake.app/".
        let dll = runtime.root.appending(path: "Fake.app/lib/dxmt/x64/d3d11.dll")
        #expect(try String(contentsOf: dll, encoding: .utf8) == "dxmt")
        #expect(runtime.dxmtDirectory.path == runtime.root.appending(path: "Fake.app/lib/dxmt").path)
        #expect(manager.installed(manifest) != nil)

        var newerOverlay = manifest
        newerOverlay.overlay?.sha256 = String(repeating: "a", count: 64)
        #expect(manager.installed(newerOverlay) == nil)
        #expect(!manifest.isSameBuild(as: newerOverlay))
        #expect(manifest.downloadSize == manifest.size + 1)
    }

    @Test func decodesManifestList() throws {
        let json = """
        [{"id": "w", "name": "Wine", "version": "11", "url": "https://example.invalid/w.tar.xz",
          "sha256": "ABC", "size": 10, "license": "LGPL-2.1", "sourceURL": "https://example.invalid",
          "binPath": "Wine.app/bin"}]
        """
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appending(path: "runtimes.json")
        try json.write(to: file, atomically: true, encoding: .utf8)
        let manifests = try RuntimeManifest.loadAll(from: file)
        #expect(manifests.map(\.id) == ["w"])
        #expect(manifests[0].features.isEmpty)
        #expect(manifests[0].sha256 == "abc")
    }

    @Test func decodesRuntimeFeatures() throws {
        let json = """
        {"id": "w", "name": "Wine", "version": "11", "url": "https://example.invalid/w.tar.xz",
         "sha256": "abc", "size": 10, "license": "LGPL-2.1", "sourceURL": "https://example.invalid",
         "binPath": "Wine.app/wine/bin", "features": ["dxmt", "msync", "future"]}
        """
        let manifest = try JSONDecoder().decode(RuntimeManifest.self, from: Data(json.utf8))
        #expect(manifest.supports(.dxmt))
        #expect(manifest.supports(.msync))
        let runtime = InstalledRuntime(manifest: manifest, root: URL(fileURLWithPath: "/R"))
        #expect(runtime.dxmtDirectory.path == "/R/Wine.app/wine/lib/dxmt")
    }
}

@Suite struct BottleStoreTests {
    @Test func createListLoadDelete() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = BottleStore(root: dir)

        let steam = try store.create(name: "Steam", runtimeID: "wine-11")
        _ = try store.create(name: "Jogos Antigos", runtimeID: "wine-11", windowsVersion: .winxp)
        #expect(store.list().map(\.name) == ["Jogos Antigos", "Steam"])

        let loaded = try store.load(folder: steam.folder)
        #expect(loaded.id == steam.id)
        #expect(loaded.prefix.lastPathComponent == "prefix")
        #expect(!loaded.isInitialized)

        try store.delete(steam)
        #expect(store.list().map(\.name) == ["Jogos Antigos"])
    }

    @Test func rejectsDuplicateAndEmptyNames() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = BottleStore(root: dir)
        _ = try store.create(name: "Steam", runtimeID: "w")
        #expect(throws: BottleError.nameTaken("steam")) { try store.create(name: "steam", runtimeID: "w") }
        #expect(throws: BottleError.invalidName) { try store.create(name: "  ", runtimeID: "w") }
    }

    @Test func mapsWindowsPathsIntoDriveC() {
        var bottle = Bottle(name: "B", runtimeID: "w")
        bottle.folder = URL(fileURLWithPath: "/Bottles/B")
        #expect(bottle.unixPath(forWindowsPath: #"C:\Program Files (x86)\Steam\steam.exe"#)?.path
                == "/Bottles/B/prefix/drive_c/Program Files (x86)/Steam/steam.exe")
        #expect(bottle.unixPath(forWindowsPath: "c:/x.exe")?.path == "/Bottles/B/prefix/drive_c/x.exe")
        #expect(bottle.unixPath(forWindowsPath: #"D:\x.exe"#) == nil)
    }

    @Test func folderNamesAreSafe() {
        let id = UUID(uuidString: "12345678-0000-0000-0000-000000000000")!
        #expect(BottleStore.folderName(for: "Jogos é Ação/2", id: id) == "Jogos-e-Acao-2-12345678")
        #expect(BottleStore.folderName(for: "日本", id: id) == "garrafa-12345678")
    }
}

@Suite struct WineEnvironmentTests {
    let runtime = InstalledRuntime(
        manifest: RuntimeManifest(id: "w", name: "W", version: "1", url: URL(string: "https://example.invalid")!,
                                  sha256: "", size: 0, license: "", sourceURL: URL(string: "https://example.invalid")!,
                                  binPath: "Wine.app/bin"),
        root: URL(fileURLWithPath: "/R"))

    func bottle() -> Bottle {
        var bottle = Bottle(name: "B", runtimeID: "w", environment: ["CUSTOM": "1", "WINEDEBUG": "+relay"],
                            dllOverrides: ["d3d11": "n,b"])
        bottle.folder = URL(fileURLWithPath: "/Bottles/B")
        return bottle
    }

    @Test func buildsIsolatedEnvironment() {
        let env = WineEnvironment.make(for: bottle(), runtime: runtime,
                                       base: ["HOME": "/Users/x", "DYLD_INSERT_LIBRARIES": "/evil", "PYTHONPATH": "/p"])
        #expect(env["HOME"] == "/Users/x")
        #expect(env["DYLD_INSERT_LIBRARIES"] == nil)
        #expect(env["PYTHONPATH"] == nil)
        #expect(env["WINEPREFIX"] == "/Bottles/B/prefix")
        #expect(env["PATH"]?.hasPrefix("/R/Wine.app/bin:") == true)
        #expect(env["ROSETTA_ADVERTISE_AVX"] == "1")
    }

    @Test func msyncNeedsRuntimeAndBottle() {
        var bottle = bottle()
        bottle.msync = true
        #expect(WineEnvironment.make(for: bottle, runtime: runtime, base: [:])["WINEMSYNC"] == nil)

        var capable = runtime
        capable.manifest.features = ["msync"]
        #expect(WineEnvironment.make(for: bottle, runtime: capable, base: [:])["WINEMSYNC"] == "1")
        bottle.msync = false
        #expect(WineEnvironment.make(for: bottle, runtime: capable, base: [:])["WINEMSYNC"] == nil)
    }

    @Test func performanceHUDFollowsBackend() {
        var bottle = bottle()
        #expect(WineEnvironment.make(for: bottle, runtime: runtime, base: [:])["MTL_HUD_ENABLED"] == nil)
        bottle.performanceHUD = true
        #expect(WineEnvironment.make(for: bottle, runtime: runtime, base: [:])["MTL_HUD_ENABLED"] == "1")
        #expect(WineEnvironment.make(for: bottle, runtime: runtime, base: [:])["DXVK_HUD"] == nil)
        bottle.graphics = .dxvk
        #expect(WineEnvironment.make(for: bottle, runtime: runtime, base: [:])["DXVK_HUD"] == "fps,devinfo")
    }

    @Test func bottleSettingsWin() {
        let env = WineEnvironment.make(for: bottle(), runtime: runtime, extraOverrides: ["mscoree": ""], base: [:])
        #expect(env["WINEDEBUG"] == "+relay")
        #expect(env["CUSTOM"] == "1")
        #expect(env["WINEDLLOVERRIDES"] == "d3d11=n,b;mscoree=")
    }
}

@Suite struct ProgramScannerTests {
    @Test func findsStartMenuAndDesktopShortcuts() throws {
        let driveC = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: driveC) }
        func touch(_ path: String) throws {
            let url = driveC.appending(path: path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            FileManager.default.createFile(atPath: url.path, contents: Data())
        }
        try touch("ProgramData/Microsoft/Windows/Start Menu/Programs/Steam/Steam.lnk")
        try touch("ProgramData/Microsoft/Windows/Start Menu/Programs/Steam/Uninstall Steam.lnk")
        try touch("users/winhub/AppData/Roaming/Microsoft/Windows/Start Menu/Programs/Notepad++.lnk")
        try touch("users/Public/Desktop/Steam.lnk")
        try touch("users/winhub/Desktop/notes.txt")

        let names = ProgramScanner.programs(driveC: driveC).map(\.name)
        #expect(names == ["Notepad++", "Steam"])
    }
}

/// Runs only with `RUN_WINE_TESTS=1` and `WINHUB_WINE_ARCHIVE` + `WINHUB_WINE_SHA256` pointing to a real Wine build.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["RUN_WINE_TESTS"] == "1"))
struct WineIntegrationTests {
    @Test(.timeLimit(.minutes(5)))
    func createsBottleAndRunsCmd() async throws {
        let env = ProcessInfo.processInfo.environment
        let archive = URL(fileURLWithPath: try #require(env["WINHUB_WINE_ARCHIVE"]))
        let manifest = RuntimeManifest(id: "integration", name: "Wine", version: "test", url: archive,
                                       sha256: try #require(env["WINHUB_WINE_SHA256"]), size: 0, license: "LGPL-2.1",
                                       sourceURL: URL(string: "https://www.winehq.org")!,
                                       binPath: env["WINHUB_WINE_BINPATH"] ?? "Wine Devel.app/Contents/Resources/wine/bin")
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let runtime = try RuntimeManager(root: dir.appending(path: "runtimes")).installArchive(at: archive, manifest: manifest)
        let bottle = try BottleStore(root: dir.appending(path: "bottles")).create(name: "Teste", runtimeID: manifest.id)
        let launcher = WineLauncher(runtime: runtime)

        try await launcher.initialize(bottle)
        #expect(bottle.isInitialized)

        let status = try await launcher.run(bottle, ["cmd", "/c", "ver"], logName: "ver")
        try await launcher.shutdown(bottle)
        #expect(status == 0)
        let log = try String(contentsOf: launcher.logURL(bottle, "ver"), encoding: .utf8)
        #expect(log.contains("Microsoft Windows"))
    }
}

@Suite struct AppLauncherBuilderTests {
    @Test func createsLauncherThatForwardsToWinHub() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        var bottle = Bottle(name: "Jogos d'Ação", runtimeID: "w")
        bottle.folder = dir.appending(path: "bottles/jogos")
        let program = InstalledProgram(name: "Steam: Cliente",
                                       shortcut: bottle.driveC.appending(path: "Start Menu/C++ & Co/Steam.lnk"))
        let builder = AppLauncherBuilder(root: dir.appending(path: "Applications"))

        let app = try builder.create(for: program, in: bottle)
        #expect(app.lastPathComponent == "Steam- Cliente.app")
        #expect(app.deletingLastPathComponent().lastPathComponent == "Jogos d'Ação")
        #expect(builder.exists(for: program, in: bottle))

        let info = try #require(NSDictionary(contentsOf: app.appending(path: "Contents/Info.plist")))
        #expect(info["CFBundleExecutable"] as? String == "launcher")
        #expect(info["LSUIElement"] as? Bool == true)

        let script = app.appending(path: "Contents/MacOS/launcher")
        #expect(FileManager.default.isExecutableFile(atPath: script.path))
        let text = try String(contentsOf: script, encoding: .utf8)
        #expect(text.contains("exec /usr/bin/open 'winhub://open?bottle=\(bottle.id.uuidString)&shortcut="))
        let check = try ProcessRunner.run(URL(fileURLWithPath: "/bin/sh"), arguments: ["-n", script.path])
        #expect(check.status == 0)

        try builder.removeAll(for: bottle)
        #expect(!builder.exists(for: program, in: bottle))
    }

    @Test func openURLRoundTripsThePath() throws {
        var bottle = Bottle(name: "B", runtimeID: "w")
        bottle.folder = URL(fileURLWithPath: "/Bottles/B")
        let program = InstalledProgram(name: "X", shortcut: URL(fileURLWithPath: "/Bottles/B/prefix/drive_c/A b/C++ & d?e#f.lnk"))
        let url = AppLauncherBuilder.openURL(for: program, in: bottle)
        let items = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        #expect(items.first { $0.name == "shortcut" }?.value == program.shortcut.path)
        #expect(items.first { $0.name == "bottle" }?.value == bottle.id.uuidString)
    }

    @Test func quotesForShell() {
        #expect(AppLauncherBuilder.shellQuote("a'b c") == #"'a'\''b c'"#)
    }
}

@Suite struct ComponentAndGraphicsTests {
    func fakeDXVK(in dir: URL) throws -> (URL, ComponentManifest) {
        let content = dir.appending(path: "c/dxvk-x")
        for arch in ["x64", "x32"] {
            let folder = content.appending(path: arch)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            for dll in ["d3d10core", "d3d11"] {
                try "\(arch)-\(dll)".write(to: folder.appending(path: "\(dll).dll"), atomically: true, encoding: .utf8)
            }
        }
        let archive = dir.appending(path: "dxvk.tar.gz")
        _ = try ProcessRunner.run(URL(fileURLWithPath: "/usr/bin/tar"),
                                  arguments: ["-czf", archive.path, "-C", dir.appending(path: "c").path, "dxvk-x"])
        let manifest = ComponentManifest(id: "dxvk-test", name: "DXVK-macOS", version: "1", kind: .archive,
                                         url: URL(string: "https://example.invalid")!, sha256: try RuntimeManager.sha256(of: archive),
                                         size: 1, license: "zlib", sourceURL: URL(string: "https://example.invalid")!, path: "dxvk-x")
        return (archive, manifest)
    }

    @Test func installsArchiveAndExecutableComponents() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let manager = ComponentManager(root: dir.appending(path: "components"))
        let (archive, dxvk) = try fakeDXVK(in: dir)
        let installed = try manager.installFile(at: archive, manifest: dxvk)
        #expect(FileManager.default.fileExists(atPath: installed.payload.appending(path: "x64/d3d11.dll").path))
        #expect(manager.installed(dxvk) != nil)

        let script = dir.appending(path: "wt")
        try "#!/bin/sh\necho ok\n".write(to: script, atomically: true, encoding: .utf8)
        let wt = ComponentManifest(id: "wt", name: "winetricks", version: "1", kind: .executable,
                                   url: URL(string: "https://example.invalid")!, sha256: try RuntimeManager.sha256(of: script),
                                   size: 1, license: "LGPL-2.1", sourceURL: URL(string: "https://example.invalid")!, path: "winetricks")
        let tool = try manager.installFile(at: script, manifest: wt)
        #expect(FileManager.default.isExecutableFile(atPath: tool.payload.path))

        var bad = wt
        bad.id = "wt2"
        bad.sha256 = String(repeating: "f", count: 64)
        #expect(throws: RuntimeError.self) { try manager.installFile(at: script, manifest: bad) }
    }

    @Test func switchesBetweenDXVKAndWined3d() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let (archive, manifest) = try fakeDXVK(in: dir)
        let dxvk = try ComponentManager(root: dir.appending(path: "components")).installFile(at: archive, manifest: manifest)

        var bottle = Bottle(name: "G", runtimeID: "w")
        bottle.folder = dir.appending(path: "bottle")
        for folder in ["system32", "syswow64"] {
            try FileManager.default.createDirectory(at: bottle.driveC.appending(path: "windows/\(folder)"), withIntermediateDirectories: true)
        }
        let launcher = WineLauncher(runtime: InstalledRuntime(
            manifest: RuntimeManifest(id: "w", name: "W", version: "1", url: URL(string: "https://example.invalid")!,
                                      sha256: "", size: 0, license: "", sourceURL: URL(string: "https://example.invalid")!,
                                      binPath: "bin"),
            root: dir))

        let withDXVK = try launcher.applyGraphics(.dxvk, to: bottle, dxvk: dxvk)
        #expect(withDXVK.graphics == .dxvk)
        #expect(withDXVK.dllOverrides == ["d3d10core": "n,b", "d3d11": "n,b"])
        let copied = try String(contentsOf: bottle.driveC.appending(path: "windows/syswow64/d3d11.dll"), encoding: .utf8)
        #expect(copied == "x32-d3d11")

        let back = try launcher.applyGraphics(.wined3d, to: withDXVK, dxvk: nil)
        #expect(back.graphics == .wined3d)
        #expect(back.dllOverrides == ["d3d10core": "b", "d3d11": "b"])
        #expect(throws: RuntimeError.self) { try launcher.applyGraphics(.dxvk, to: bottle, dxvk: nil) }
    }

    @Test func switchesToDXMTAndBack() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        var bottle = Bottle(name: "G", runtimeID: "w")
        bottle.folder = dir.appending(path: "bottle")
        for folder in ["system32", "syswow64"] {
            try FileManager.default.createDirectory(at: bottle.driveC.appending(path: "windows/\(folder)"), withIntermediateDirectories: true)
        }
        var manifest = RuntimeManifest(id: "w", name: "W", version: "1", url: URL(string: "https://example.invalid")!,
                                       sha256: "", size: 0, license: "", sourceURL: URL(string: "https://example.invalid")!,
                                       binPath: "wine/bin")
        let runtime = InstalledRuntime(manifest: manifest, root: dir)
        for arch in ["x64", "x32"] {
            let folder = runtime.dxmtDirectory.appending(path: arch)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            for dll in ["d3d10core", "d3d11", "dxgi", "winemetal"] {
                try "\(arch)-\(dll)".write(to: folder.appending(path: "\(dll).dll"), atomically: true, encoding: .utf8)
            }
        }

        // A runtime without the feature refuses DXMT even if the files exist.
        #expect(throws: RuntimeError.self) { try WineLauncher(runtime: runtime).applyGraphics(.dxmt, to: bottle, dxvk: nil) }

        manifest.features = ["dxmt"]
        let launcher = WineLauncher(runtime: InstalledRuntime(manifest: manifest, root: dir))
        let withDXMT = try launcher.applyGraphics(.dxmt, to: bottle, dxvk: nil)
        #expect(withDXMT.graphics == .dxmt)
        #expect(withDXMT.dllOverrides == ["d3d10core": "n,b", "d3d11": "n,b", "dxgi": "n,b"])
        let system32 = bottle.driveC.appending(path: "windows/system32")
        #expect(try String(contentsOf: system32.appending(path: "dxgi.dll"), encoding: .utf8) == "x64-dxgi")
        #expect(try String(contentsOf: system32.appending(path: "winemetal.dll"), encoding: .utf8) == "x64-winemetal")

        let back = try launcher.applyGraphics(.wined3d, to: withDXMT, dxvk: nil)
        #expect(back.dllOverrides == ["d3d10core": "b", "d3d11": "b", "dxgi": "b"])
    }

    @Test func winetricksFindsCabextract() throws {
        var bottle = Bottle(name: "G", runtimeID: "w")
        bottle.folder = URL(fileURLWithPath: "/Bottles/G")
        let launcher = WineLauncher(runtime: InstalledRuntime(
            manifest: RuntimeManifest(id: "w", name: "W", version: "1", url: URL(string: "https://example.invalid")!,
                                      sha256: "", size: 0, license: "", sourceURL: URL(string: "https://example.invalid")!,
                                      binPath: "bin"),
            root: URL(fileURLWithPath: "/R")))
        let without = launcher.winetricksEnvironment(for: bottle, cabextract: nil)
        #expect(without["PATH"]?.hasPrefix("/R/bin:") == true)
        #expect(without["WINESERVER"] == "/R/bin/wineserver")

        let cab = ComponentManifest(id: "cab", name: "cabextract", version: "1", kind: .archive,
                                    url: URL(string: "https://example.invalid")!, sha256: "", size: 0, license: "GPL-3.0",
                                    sourceURL: URL(string: "https://example.invalid")!, path: "cabextract")
        let with = launcher.winetricksEnvironment(
            for: bottle, cabextract: InstalledComponent(manifest: cab, root: URL(fileURLWithPath: "/C/cab")))
        #expect(with["PATH"]?.hasPrefix("/C/cab/cabextract:/R/bin:") == true)
    }

    @Test func unknownBackendFallsBackToWine() throws {
        let json = #"{"id": "12345678-0000-0000-0000-000000000000", "name": "Nova", "runtimeID": "w", "graphics": "vulkan9", "msync": true}"#
        let bottle = try JSONDecoder().decode(Bottle.self, from: Data(json.utf8))
        #expect(bottle.graphics == .wined3d)
        #expect(bottle.msync)
    }

    @Test func decodesOlderBottleFiles() throws {
        let json = #"{"id": "12345678-0000-0000-0000-000000000000", "name": "Velha", "runtimeID": "w"}"#
        let bottle = try JSONDecoder().decode(Bottle.self, from: Data(json.utf8))
        #expect(bottle.graphics == .wined3d)
        #expect(bottle.windowsVersion == .win10)
        #expect(bottle.dllOverrides.isEmpty)
        #expect(!bottle.msync)
        #expect(!bottle.performanceHUD)
    }
}

/// Runs with `RUN_WINE_TESTS=1`, the Wine runtime installed by the app, and
/// `WINHUB_DXVK_ARCHIVE` / `WINHUB_WINETRICKS` pointing to the real downloads.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["RUN_WINE_TESTS"] == "1"
                && ProcessInfo.processInfo.environment["WINHUB_DXVK_ARCHIVE"] != nil))
struct ComponentIntegrationTests {
    @Test(.timeLimit(.minutes(10)))
    func dxvkAndWinetricksInRealBottle() async throws {
        let env = ProcessInfo.processInfo.environment
        let manifests = try ComponentManifest.loadAll(from: URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "Sources/WinHub/Resources/components.json"))
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let components = ComponentManager(root: dir.appending(path: "components"))
        let dxvk = try components.installFile(at: URL(fileURLWithPath: try #require(env["WINHUB_DXVK_ARCHIVE"])),
                                              manifest: try #require(manifests.first { $0.name == "DXVK-macOS" }))
        let winetricks = try components.installFile(at: URL(fileURLWithPath: try #require(env["WINHUB_WINETRICKS"])),
                                                    manifest: try #require(manifests.first { $0.name == "winetricks" }))

        // Uses the Wine that WinHub installed (run the app and download it first).
        let wineManifest = try RuntimeManifest.loadAll(from: URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "Sources/WinHub/Resources/runtimes.json"))[0]
        let runtime = try #require(RuntimeManager(root: RuntimeManager.defaultRoot).installed(wineManifest))
        let store = BottleStore(root: dir.appending(path: "bottles"))
        var bottle = try store.create(name: "Componentes", runtimeID: wineManifest.id)
        let launcher = WineLauncher(runtime: runtime)
        try await launcher.initialize(bottle)

        bottle = try launcher.applyGraphics(.dxvk, to: bottle, dxvk: dxvk)
        #expect(FileManager.default.fileExists(atPath: bottle.driveC.appending(path: "windows/system32/d3d11.dll").path))
        #expect(await (try launcher.run(bottle, ["cmd", "/c", "ver"], logName: "ver-dxvk")) == 0)

        try await launcher.runWinetricks(["fontsmooth=rgb"], in: bottle, winetricks: winetricks)
        try await launcher.shutdown(bottle)
        let userReg = try String(contentsOf: bottle.prefix.appending(path: "user.reg"), encoding: .utf8)
        #expect(userReg.contains("\"FontSmoothingType\"=dword:00000002"))
    }
}

@Suite struct WineOrphanReaperTests {
    @Test func serverDirectoryUsesHexDeviceAndInode() {
        let url = WineServerStatus.serverDirectory(device: 0x100000f, inode: 0x162c11, uid: 501)
        #expect(url.path == "/tmp/.wine-501/server-100000f-162c11")
    }

    @Test func findsProcessesReferencingServerDirectory() {
        let directory = URL(fileURLWithPath: "/tmp/.wine-501/server-100000f-162c11", isDirectory: true)
        let output = """
        p100
        cwineserver
        n/private/tmp/.wine-501/server-100000f-162c11
        n/private/tmp/.wine-501/server-100000f-162c11/lock
        p200
        cwinedevice.exe
        n/Users/me/prefix/drive_c/windows/system32
        n/private/tmp/.wine-501/server-100000f-162c11/tmpmap-587e6bbb
        p300
        csteam.exe
        n/private/tmp/.wine-501/server-100000f-162c111/tmpmap-1
        n/Users/me/other
        p400
        cservices.exe
        n/tmp/.wine-501/server-100000f-162c11
        p500
        cWinHub
        n/private/tmp/.wine-501/server-100000f-162c11/lock
        """
        let pids = WineOrphanReaper.pids(in: output, referencing: directory, excluding: 500)
        #expect(pids == [200, 400])
    }

    @Test func noServerDirectoryForMissingPrefix() {
        #expect(WineServerStatus.serverDirectory(prefix: URL(fileURLWithPath: "/nonexistent/winhub/prefix")) == nil)
        #expect(WineOrphanReaper.reap(prefix: URL(fileURLWithPath: "/nonexistent/winhub/prefix")).isEmpty)
    }

    @Test func staleSocketIsNotARunningServer() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        #expect(!WineServerStatus.isRunning(serverDirectory: dir))
        // What a wineserver killed with SIGKILL leaves: lock and socket, nobody holding the lock.
        FileManager.default.createFile(atPath: dir.appending(path: "lock").path, contents: nil)
        FileManager.default.createFile(atPath: dir.appending(path: "socket").path, contents: nil)
        #expect(!WineServerStatus.isRunning(serverDirectory: dir))
    }

    @Test func endsProcessesWhenNoServerHoldsTheLock() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        FileManager.default.createFile(atPath: dir.appending(path: "lock").path, contents: nil)
        #expect(WineServerStatus.lockOwner(serverDirectory: dir) == nil)

        // Stands in for an orphaned Wine client: its working directory is the server folder.
        let orphan = Process()
        orphan.executableURL = URL(fileURLWithPath: "/bin/sleep")
        orphan.arguments = ["60"]
        orphan.currentDirectoryURL = dir
        try orphan.run()
        defer { if orphan.isRunning { orphan.terminate() } }

        let pids = WineOrphanReaper.reap(serverDirectory: dir)
        #expect(pids == [orphan.processIdentifier])
        orphan.waitUntilExit()
        #expect(orphan.terminationReason == .uncaughtSignal)
        #expect(orphan.terminationStatus == SIGKILL)
    }

    @Test(.enabled(if: FileManager.default.isExecutableFile(atPath: "/usr/bin/python3")))
    func leavesProcessesAloneWhileServerHoldsTheLock() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let lock = dir.appending(path: "lock")
        FileManager.default.createFile(atPath: lock.path, contents: nil)

        // Holds an fcntl write lock on `lock` like a live wineserver, from inside the folder.
        let server = Process()
        server.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        server.arguments = ["-I", "-c", """
            import fcntl, sys, time
            f = open(sys.argv[1], 'r+'); fcntl.lockf(f, fcntl.LOCK_EX); print('locked', flush=True); time.sleep(60)
            """, lock.path]
        server.currentDirectoryURL = dir
        let pipe = Pipe()
        server.standardOutput = pipe
        try server.run()
        defer { server.terminate(); server.waitUntilExit() }
        _ = pipe.fileHandleForReading.availableData  // waits for "locked"

        #expect(WineServerStatus.lockOwner(serverDirectory: dir) == server.processIdentifier)
        #expect(WineServerStatus.isRunning(serverDirectory: dir))
        #expect(WineOrphanReaper.reap(serverDirectory: dir).isEmpty)
        #expect(server.isRunning)
    }
}
