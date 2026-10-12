import Foundation
import Testing
@testable import WinHubRuntime

/// Engines that pick the Direct3D themselves (`backend-dispatch`): nothing is copied into bottles.
@Suite struct DispatchedGraphicsTests {
    /// A runtime whose `wine` is a script that only logs its arguments; `features` as given.
    func makeRuntime(in dir: URL, features: [String]) throws -> InstalledRuntime {
        let bin = dir.appending(path: "runtime/wine/bin", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
        let wine = bin.appending(path: "wine")
        try "#!/bin/sh\necho \"$@\" >> \"\(dir.path)/wine-calls.txt\"\n".write(to: wine, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: wine.path)
        // Wine's own Direct3D DLLs, which go back into the prefix.
        for folder in ["x86_64-windows", "i386-windows"] {
            let lib = bin.deletingLastPathComponent().appending(path: "lib/wine/\(folder)", directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: lib, withIntermediateDirectories: true)
            for dll in GraphicsBackend.replacedDLLs + ["winemetal"] {
                try "wine-\(folder)-\(dll)".write(to: lib.appending(path: "\(dll).dll"), atomically: true, encoding: .utf8)
            }
        }
        let manifest = RuntimeManifest(id: "w", name: "W", version: "1", url: URL(string: "https://example.invalid")!,
                                       sha256: "", size: 0, license: "", sourceURL: URL(string: "https://example.invalid")!,
                                       binPath: "wine/bin", features: features)
        return InstalledRuntime(manifest: manifest, root: dir.appending(path: "runtime"))
    }

    func makeBottle(in dir: URL) throws -> Bottle {
        var bottle = Bottle(name: "G", runtimeID: "w")
        bottle.folder = dir.appending(path: "bottle", directoryHint: .isDirectory)
        for folder in ["system32", "syswow64"] {
            try FileManager.default.createDirectory(at: bottle.driveC.appending(path: "windows/\(folder)"),
                                                    withIntermediateDirectories: true)
        }
        return bottle
    }

    @Test func replacesFoldersBeforeTheOverlay() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        var (archive, manifest) = try makeFakeRuntimeArchive(in: dir)
        let overlay = dir.appending(path: "overlay", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: overlay.appending(path: "bin"), withIntermediateDirectories: true)
        for name in ["wine", "wineserver"] {
            let file = overlay.appending(path: "bin/\(name)")
            try "#!/bin/sh\n# engine\n".write(to: file, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: file.path)
        }
        let overlayArchive = dir.appending(path: "overlay.tar.xz")
        let tar = try ProcessRunner.run(URL(fileURLWithPath: "/usr/bin/tar"),
                                        arguments: ["-cJf", overlayArchive.path, "-C", overlay.path, "bin"])
        #expect(tar.status == 0)
        manifest.overlay = .init(url: URL(string: "https://example.invalid/o.tar.xz")!,
                                 sha256: try RuntimeManager.sha256(of: overlayArchive), size: 1, replace: ["bin"])
        let manager = RuntimeManager(root: dir.appending(path: "runtimes"))

        let runtime = try manager.installArchive(at: archive, overlay: overlayArchive, manifest: manifest)
        #expect(try String(contentsOf: runtime.wine, encoding: .utf8).contains("# engine"))

        var escaping = manifest
        escaping.overlay?.replace = ["../outside"]
        #expect(throws: RuntimeError.self) {
            try manager.installArchive(at: archive, overlay: overlayArchive, manifest: escaping)
        }
    }

    @Test func replaceTargetsStayInsideTheWineFolder() {
        let wine = URL(fileURLWithPath: "/R/wine")
        #expect(RuntimeManager.replaceTarget("lib/wine", in: wine)?.path == "/R/wine/lib/wine")
        #expect(RuntimeManager.replaceTarget("../lib", in: wine) == nil)
        #expect(RuntimeManager.replaceTarget("/bin", in: wine) == nil)
        #expect(RuntimeManager.replaceTarget("", in: wine) == nil)
        #expect(RuntimeManager.replaceTarget("lib/./wine", in: wine) == nil)
    }

    @Test func decodesOverlayReplace() throws {
        let json = #"{"url": "https://example.invalid/o", "sha256": "AB", "size": 3, "replace": ["bin", "lib/wine"]}"#
        let overlay = try JSONDecoder().decode(RuntimeManifest.Overlay.self, from: Data(json.utf8))
        #expect(overlay.replace == ["bin", "lib/wine"])
        #expect(overlay.sha256 == "ab")
        let older = #"{"url": "https://example.invalid/o", "sha256": "ab", "size": 3}"#
        #expect(try JSONDecoder().decode(RuntimeManifest.Overlay.self, from: Data(older.utf8)).replace.isEmpty)
    }

    @Test func environmentTellsTheEngineWhatToUse() throws {
        var bottle = Bottle(name: "B", runtimeID: "w", graphics: .auto)
        bottle.folder = URL(fileURLWithPath: "/Bottles/B")
        let plain = InstalledRuntime(
            manifest: RuntimeManifest(id: "w", name: "W", version: "1", url: URL(string: "https://example.invalid")!,
                                      sha256: "", size: 0, license: "", sourceURL: URL(string: "https://example.invalid")!,
                                      binPath: "bin"),
            root: URL(fileURLWithPath: "/R"))
        #expect(WineEnvironment.make(for: bottle, runtime: plain, base: [:])["WINHUB_GRAPHICS_BACKEND"] == nil)

        var dispatching = plain
        dispatching.manifest.features = ["backend-dispatch"]
        let home = URL(fileURLWithPath: "/Home/WinHub")
        var env = WineEnvironment.make(for: bottle, runtime: dispatching, winhubHome: home, base: [:])
        #expect(env["WINHUB_GRAPHICS_BACKEND"] == "auto")
        #expect(env["WINHUB_COMPAT_RULES"] == "/Bottles/B/compat-rules.json")
        #expect(env["WINHUB_HOME"] == "/Home/WinHub")
        #expect(env["WINHUB_D3DMETAL_DIR"] == nil)

        env = WineEnvironment.make(for: bottle, runtime: dispatching, d3dmetal: URL(fileURLWithPath: "/GPTK/lib"),
                                   winhubHome: home, base: [:])
        #expect(env["WINHUB_D3DMETAL_DIR"] == "/GPTK/lib")
        #expect(env["CX_APPLEGPTK_LIBD3DSHARED_PATH"] == "/GPTK/lib/external/libd3dshared.dylib")
    }

    @Test func switchingCopiesNothingAndUndoesEarlierCopies() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let runtime = try makeRuntime(in: dir, features: ["backend-dispatch", "dxmt", "dxvk"])
        var bottle = try makeBottle(in: dir)
        // Left by an engine that copied DXMT into the prefix.
        let system32 = bottle.driveC.appending(path: "windows/system32")
        for dll in ["d3d11", "dxgi", "d3d10core", "winemetal"] {
            try "dxmt-\(dll)".write(to: system32.appending(path: "\(dll).dll"), atomically: true, encoding: .utf8)
        }
        bottle.dllOverrides = ["d3d11": "n,b", "dxgi": "n,b", "d3d10core": "n,b", "xinput1_3": "n"]
        bottle.graphics = .dxmt

        let launcher = WineLauncher(runtime: runtime)
        let updated = try launcher.applyGraphics(.auto, to: bottle, dxvk: nil)
        #expect(updated.graphics == .auto)
        #expect(updated.dllOverrides == ["xinput1_3": "n"])
        #expect(try String(contentsOf: system32.appending(path: "d3d11.dll"), encoding: .utf8) == "wine-x86_64-windows-d3d11")
        // The copied DXMT bridge gives way to the engine's own, which Wine needs in system32.
        #expect(try String(contentsOf: system32.appending(path: "winemetal.dll"), encoding: .utf8)
                == "wine-x86_64-windows-winemetal")

        // D3DMetal and "automatic" need such an engine.
        let older = try makeRuntime(in: dir.appending(path: "older"), features: ["dxmt"])
        #expect(throws: GraphicsError.unsupported(.d3dmetal)) {
            try WineLauncher(runtime: older).applyGraphics(.d3dmetal, to: bottle, dxvk: nil)
        }
    }

    @Test func findsD3DMetalInsideTheToolkit() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let lib = dir.appending(path: "Toolkit/redist/lib", directoryHint: .isDirectory)
        for path in ["wine/x86_64-windows/d3d12.dll", "wine/x86_64-unix/d3d12.so"] {
            let file = lib.appending(path: path)
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try "x".write(to: file, atomically: true, encoding: .utf8)
        }
        #expect(D3DMetal.resolve(dir.appending(path: "Toolkit")) == nil)  // no framework yet
        try FileManager.default.createDirectory(at: lib.appending(path: "external/D3DMetal.framework"),
                                                withIntermediateDirectories: true)
        #expect(D3DMetal.resolve(dir.appending(path: "Toolkit"))?.path == lib.path)
        #expect(D3DMetal.resolve(dir.appending(path: "Toolkit/redist"))?.path == lib.path)
        #expect(D3DMetal.resolve(lib)?.path == lib.path)
        #expect(D3DMetal.resolve(dir) == nil)
    }

    @Test func programRulesKeepOtherRules() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let bottle = try makeBottle(in: dir)
        let user = #"{"version": 1, "rules": [{"desc": "mine", "match": {"type": "steam_game_id", "game_id": "1"}, "hacks": [{"type": "env_vars", "vars": {"A": "1"}}]}]}"#
        try Data(user.utf8).write(to: CompatRules.url(for: bottle))
        let program = #"C:\Games\Game\game.exe"#

        try CompatRules.setProgramBackend(.dxmt, program: program, in: bottle)
        #expect(CompatRules.programBackend(program, in: bottle) == .dxmt)
        try CompatRules.setProgramBackend(.dxvk, program: program, in: bottle)
        #expect(CompatRules.programBackend(program, in: bottle) == .dxvk)

        let root = try JSONSerialization.jsonObject(with: Data(contentsOf: CompatRules.url(for: bottle))) as? [String: Any]
        let rules = root?["rules"] as? [[String: Any]] ?? []
        #expect(root?["version"] as? Int == 1)
        #expect(rules.count == 2)
        #expect(rules.first?["desc"] as? String == "mine")
        let hack = (rules.last?["hacks"] as? [[String: Any]])?.first
        #expect(hack?["type"] as? String == "graphics_backend")
        #expect(hack?["force"] as? Bool == true)
        #expect((rules.last?["match"] as? [String: String])?["suffix"] == program)

        try CompatRules.setProgramBackend(nil, program: program, in: bottle)
        #expect(CompatRules.programBackend(program, in: bottle) == nil)
        try CompatRules.setProgramBackend(.auto, program: program, in: bottle)
        #expect(CompatRules.programBackend(program, in: bottle) == nil)
    }

    @Test func migratesBottlesFromCopyingEngines() async throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let runtime = try makeRuntime(in: dir, features: ["backend-dispatch", "dxmt"])
        var bottle = try makeBottle(in: dir)
        let program = #"C:\Games\Game\game.exe"#
        let gameFolder = bottle.driveC.appending(path: "Games/Game", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: gameFolder, withIntermediateDirectories: true)
        try "exe".write(to: gameFolder.appending(path: "game.exe"), atomically: true, encoding: .utf8)
        for dll in ["d3d11", "dxgi", "d3d10core", "winemetal"] {
            try "copied".write(to: gameFolder.appending(path: "\(dll).dll"), atomically: true, encoding: .utf8)
        }
        bottle.dllOverrides = ["d3d11": "n,b", "dxgi": "n,b", "d3d10core": "n,b"]
        bottle.graphics = .wined3d
        bottle.programGraphics = [program: .dxmt]

        let launcher = WineLauncher(runtime: runtime)
        let migrated = try #require(try await launcher.migrateToDispatchedGraphics(bottle))
        #expect(migrated.dllOverrides.isEmpty)
        #expect(migrated.programGraphics == [program: .dxmt])
        #expect(CompatRules.programBackend(program, in: migrated) == .dxmt)
        #expect(!FileManager.default.fileExists(atPath: gameFolder.appending(path: "d3d11.dll").path))
        #expect(FileManager.default.fileExists(atPath: gameFolder.appending(path: "game.exe").path))
        let calls = try String(contentsOf: dir.appending(path: "wine-calls.txt"), encoding: .utf8)
        #expect(calls.contains(#"reg delete HKCU\Software\Wine\AppDefaults\game.exe\DllOverrides /f"#))

        let syswow64 = bottle.driveC.appending(path: "windows/syswow64")
        #expect(try String(contentsOf: syswow64.appending(path: "winemetal.dll"), encoding: .utf8)
                == "wine-i386-windows-winemetal")

        // Nothing left to do; a DLL the game brings itself is never touched afterwards.
        try "game's own".write(to: gameFolder.appending(path: "d3d11.dll"), atomically: true, encoding: .utf8)
        #expect(try await launcher.migrateToDispatchedGraphics(migrated) == nil)
        let updated = try await launcher.applyProgramGraphics(.dxvk, program: program, in: migrated, dxvk: nil)
        #expect(updated.programGraphics == [program: .dxvk])
        #expect(try String(contentsOf: gameFolder.appending(path: "d3d11.dll"), encoding: .utf8) == "game's own")
    }
}
