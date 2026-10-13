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
