import Foundation
import Testing
@testable import WinHubRuntime

@Suite struct SteamWebHelperWrapperTests {
    struct Fixture {
        let dir: URL
        let bottle: Bottle
        let wrapper: SteamWebHelperWrapper

        var cef: URL { bottle.driveC.appending(path: "Program Files (x86)/Steam/bin/cef/cef.win64") }
        var helper: URL { cef.appending(path: "steamwebhelper.exe") }
        var real: URL { cef.appending(path: "steamwebhelper_real.exe") }

        init() throws {
            dir = try makeTempDirectory()
            var bottle = Bottle(name: "Steam", runtimeID: "w")
            bottle.folder = dir.appending(path: "bottle")
            self.bottle = bottle
            let file = dir.appending(path: "steamwebhelper-wrapper.exe")
            try Data("wrapper v2 \(SteamWebHelperWrapper.marker)".utf8).write(to: file)
            wrapper = SteamWebHelperWrapper(wrapper: file)
        }

        func write(_ text: String, to url: URL) throws {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(text.utf8).write(to: url)
        }

        let current = "wrapper v2 \(SteamWebHelperWrapper.marker)"

        func read(_ url: URL) -> String? {
            (try? Data(contentsOf: url)).map { String(decoding: $0, as: UTF8.self) }
        }
    }

    @Test func doesNothingWithoutSteam() throws {
        let f = try Fixture()
        defer { try? FileManager.default.removeItem(at: f.dir) }
        #expect(try f.wrapper.install(in: f.bottle) == false)
        #expect(!FileManager.default.fileExists(atPath: f.cef.path))
    }

    @Test func wrapsSteamsHelper() throws {
        let f = try Fixture()
        defer { try? FileManager.default.removeItem(at: f.dir) }
        try f.write("steam v1", to: f.helper)

        #expect(try f.wrapper.install(in: f.bottle))
        #expect(f.read(f.helper) == f.current)
        #expect(f.read(f.real) == "steam v1")
    }

    @Test func leavesInstalledWrapperAlone() throws {
        let f = try Fixture()
        defer { try? FileManager.default.removeItem(at: f.dir) }
        try f.write(f.current, to: f.helper)
        try f.write("steam v1", to: f.real)

        #expect(try f.wrapper.install(in: f.bottle))
        #expect(f.read(f.helper) == f.current)
        #expect(f.read(f.real) == "steam v1")
    }

    @Test func rewrapsAfterSteamUpdate() throws {
        let f = try Fixture()
        defer { try? FileManager.default.removeItem(at: f.dir) }
        try f.write("steam v2", to: f.helper)
        try f.write("steam v1", to: f.real)

        #expect(try f.wrapper.install(in: f.bottle))
        #expect(f.read(f.helper) == f.current)
        #expect(f.read(f.real) == "steam v2")
    }

    @Test func restoresMissingWrapper() throws {
        let f = try Fixture()
        defer { try? FileManager.default.removeItem(at: f.dir) }
        try f.write("steam v1", to: f.real)

        #expect(try f.wrapper.install(in: f.bottle))
        #expect(f.read(f.helper) == f.current)
        #expect(f.read(f.real) == "steam v1")
    }

    @Test func upgradesOlderWrapper() throws {
        let f = try Fixture()
        defer { try? FileManager.default.removeItem(at: f.dir) }
        try f.write("wrapper v1 \(SteamWebHelperWrapper.marker)", to: f.helper)
        try f.write("steam v1", to: f.real)

        #expect(try f.wrapper.install(in: f.bottle))
        #expect(f.read(f.helper) == f.current)
        #expect(f.read(f.real) == "steam v1")
    }

    @Test func wrapperSourceEmbedsTheMarker() throws {
        let source = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "Support/steamwebhelper-wrapper/steamwebhelper_wrapper.c")
        let text = try String(contentsOf: source, encoding: .utf8)
        #expect(text.contains("\"\(SteamWebHelperWrapper.marker)\""))
    }

    @Test func reportsWrapperWithoutRealHelper() throws {
        let f = try Fixture()
        defer { try? FileManager.default.removeItem(at: f.dir) }
        try f.write(f.current, to: f.helper)
        #expect(try f.wrapper.install(in: f.bottle) == false)
    }
}

@Suite struct SteamWebHelperWrapperLocationTests {
    @Test func prefersTheAppsResources() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let bundled = dir.appending(path: "steamwebhelper-wrapper.exe")
        let dev = dir.appending(path: "dev.exe")
        for file in [bundled, dev] { FileManager.default.createFile(atPath: file.path, contents: Data()) }

        let env = ["WINHUB_STEAMWEBHELPER_WRAPPER": dev.path]
        #expect(SteamWebHelperWrapper.locate(bundled: bundled, environment: env)?.wrapper == bundled)
        #expect(SteamWebHelperWrapper.locate(bundled: nil, environment: env)?.wrapper == dev)
    }

    @Test func ignoresMissingFiles() {
        let env = ["WINHUB_STEAMWEBHELPER_WRAPPER": "/nonexistent/wrapper.exe"]
        #expect(SteamWebHelperWrapper.locate(bundled: nil, environment: env) == nil)
        #expect(SteamWebHelperWrapper.locate(bundled: nil, environment: [:]) == nil)
    }
}

@Suite struct WineLauncherArgumentTests {
    @Test func passesExtraArgumentsToShortcut() {
        let shortcut = URL(fileURLWithPath: "/B/prefix/drive_c/Steam.lnk")
        #expect(WineLauncher.shortcutArguments(shortcut, ["-noverifyfiles"])
                == ["start", "/wait", "/unix", "/B/prefix/drive_c/Steam.lnk", "-noverifyfiles"])
        #expect(WineLauncher.shortcutArguments(shortcut, []) == ["start", "/wait", "/unix", "/B/prefix/drive_c/Steam.lnk"])
    }

    @Test func switchesEmulatedDisplayModes() {
        #expect(WineLauncher.displayModesArguments(true)
                == ["reg", "add", #"HKCU\Software\Wine\X11 Driver"#, "/v", "EmulateModeset", "/d", "Y", "/f"])
        // "N" instead of deleting the value: `reg delete` fails when it is not there.
        #expect(WineLauncher.displayModesArguments(false)
                == ["reg", "add", #"HKCU\Software\Wine\X11 Driver"#, "/v", "EmulateModeset", "/d", "N", "/f"])
    }

    @Test func buildsArgumentsForWinesOwnTools() {
        #expect(WineLauncher.toolArguments(.configuration) == ["winecfg"])
        #expect(WineLauncher.toolArguments(.registryEditor) == ["regedit"])
        #expect(WineLauncher.toolArguments(.controlPanel) == ["control"])
        #expect(WineLauncher.toolArguments(.taskManager) == ["taskmgr"])
        // `cmd` needs a console window of its own, and `start` opens one.
        #expect(WineLauncher.toolArguments(.commandPrompt) == ["start", "cmd"])
        #expect(WineTool.allCases.count == 5)
        #expect(WineTool.allCases.allSatisfy { !$0.systemImage.isEmpty })
    }
}
