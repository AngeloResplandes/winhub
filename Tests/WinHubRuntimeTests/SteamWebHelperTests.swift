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

    @Test func whileRunningWrapsOnlyANewInstall() throws {
        let f = try Fixture()
        defer { try? FileManager.default.removeItem(at: f.dir) }
        try f.write("steam v1", to: f.helper)

        #expect(try f.wrapper.install(in: f.bottle, onlyIfNeverWrapped: true))
        #expect(f.read(f.helper) == f.current)
        #expect(f.read(f.real) == "steam v1")
    }

    /// Steam started without `-noverifyfiles` puts its helper back and restarts;
    /// wrapping it again while it runs would make both undo each other forever.
    @Test func whileRunningLeavesARestoredHelperAlone() throws {
        let f = try Fixture()
        defer { try? FileManager.default.removeItem(at: f.dir) }
        try f.write("steam v1", to: f.helper)
        try f.write("steam v1", to: f.real)

        #expect(try f.wrapper.install(in: f.bottle, onlyIfNeverWrapped: true) == false)
        #expect(f.read(f.helper) == "steam v1")
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

@Suite struct WineLauncherArgumentTests {
    @Test func passesExtraArgumentsToShortcut() {
        let shortcut = URL(fileURLWithPath: "/B/prefix/drive_c/Steam.lnk")
        #expect(WineLauncher.shortcutArguments(shortcut, ["-noverifyfiles"])
                == ["start", "/wait", "/unix", "/B/prefix/drive_c/Steam.lnk", "-noverifyfiles"])
        #expect(WineLauncher.shortcutArguments(shortcut, []) == ["start", "/wait", "/unix", "/B/prefix/drive_c/Steam.lnk"])
    }
}
