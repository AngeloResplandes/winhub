import Foundation
import Testing
@testable import WinHubRuntime

@Suite struct WineServerStatusTests {
    @Test func executablePathOfARunningProcess() throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sleep")
        process.arguments = ["30"]
        try process.run()
        defer { process.terminate(); process.waitUntilExit() }
        #expect(WineServerStatus.executablePath(pid: process.processIdentifier) == "/bin/sleep")
    }

    @Test func noExecutablePathForAProcessThatExited() throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/true")
        try process.run()
        process.waitUntilExit()
        #expect(WineServerStatus.executablePath(pid: process.processIdentifier) == nil)
    }

    @Test func noServerForAPrefixThatNeverRan() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        #expect(WineServerStatus.serverPID(prefix: dir) == nil)
        #expect(WineServerStatus.serverPID(prefix: dir.appending(path: "missing")) == nil)
    }
}

@Suite struct BottleSessionTests {
    @Test func writesAndReadsTheRecord() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let bottle = try BottleStore(root: dir).create(name: "Jogo", runtimeID: "w")
        #expect(BottleSession.read(bottle) == nil)

        let session = BottleSession(pid: 123, appPath: "/Applications/WinHub.app/Contents/MacOS/WinHub",
                                    startedAt: Date(timeIntervalSince1970: 1_000_000))
        try BottleSession.write(session, to: bottle)
        #expect(BottleSession.read(bottle) == session)
        #expect(FileManager.default.fileExists(atPath: bottle.folder.appending(path: "session.json").path))
    }

    @Test func anUnreadableRecordIsIgnored() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let bottle = try BottleStore(root: dir).create(name: "Jogo", runtimeID: "w")
        try Data("{".utf8).write(to: bottle.folder.appending(path: "session.json"))
        #expect(BottleSession.read(bottle) == nil)
    }

    @Test func currentIsThisProcess() {
        let current = BottleSession.current
        #expect(current.pid == getpid())
        #expect(current.appPath == WineServerStatus.executablePath(pid: getpid()))
    }
}
