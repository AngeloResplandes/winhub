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

@Suite struct BottleGuardTests {
    let engine = "/Users/me/Library/Application Support/WinHub/Runtimes/r3/Wine.app/Contents/Resources/wine/bin/wineserver"
    let otherEngine = "/Users/me/Library/Application Support/WinHub/Runtimes/r2/Wine.app/Contents/Resources/wine/bin/wineserver"
    let installed = "/Applications/WinHub.app/Contents/MacOS/WinHub"

    func conflict(server: String?, session: BottleSession?, sessionExecutable: String?, ownPID: pid_t = 20) -> BottleConflict? {
        BottleGuard.conflict(serverPath: server, ownWineserver: engine, session: session,
                             sessionExecutable: sessionExecutable, ownPID: ownPID)
    }

    @Test func aStoppedBottleIsFreeWhateverItsRecord() {
        #expect(conflict(server: nil, session: BottleSession(pid: 10, appPath: installed), sessionExecutable: installed) == nil)
        #expect(conflict(server: nil, session: nil, sessionExecutable: nil) == nil)
    }

    @Test func anotherOpenWinHubHoldsTheBottle() {
        #expect(conflict(server: engine, session: BottleSession(pid: 10, appPath: installed), sessionExecutable: installed)
                == .otherWinHub(appPath: installed))
    }

    @Test func aWinHubThatQuitNoLongerHoldsIt() {
        #expect(conflict(server: engine, session: BottleSession(pid: 10, appPath: installed), sessionExecutable: nil) == nil)
    }

    @Test func aReusedPidDoesNotHoldIt() {
        #expect(conflict(server: engine, session: BottleSession(pid: 10, appPath: installed), sessionExecutable: "/bin/zsh") == nil)
    }

    @Test func thisWinHubsOwnRecordIsFree() {
        #expect(conflict(server: engine, session: BottleSession(pid: 20, appPath: installed), sessionExecutable: installed) == nil)
    }

    @Test func anotherEngineHoldsTheBottle() {
        #expect(conflict(server: otherEngine, session: nil, sessionExecutable: nil) == .otherEngine(wineserver: otherEngine))
    }

    @Test func anotherWinHubIsReportedBeforeTheEngine() {
        #expect(conflict(server: otherEngine, session: BottleSession(pid: 10, appPath: installed), sessionExecutable: installed)
                == .otherWinHub(appPath: installed))
    }

    @Test func theSameEngineSpelledDifferentlyIsFree() {
        let found = BottleGuard.conflict(serverPath: "/private/tmp/w/bin/wineserver", ownWineserver: "/tmp/w/bin/../bin/wineserver",
                                         session: nil, sessionExecutable: nil, ownPID: 20)
        #expect(found == nil)
    }

    func state(_ id: UUID, _ name: String, steam: Bool, running: Bool) -> BottleGuard.BottleState {
        BottleGuard.BottleState(id: id, name: name, hasSteam: steam, isRunning: running)
    }

    @Test func steamInAnotherRunningBottleBlocksOpening() {
        let target = UUID(), other = UUID()
        let found = BottleGuard.steamConflict(opening: target, bottles: [
            state(target, "Steam", steam: true, running: false),
            state(other, "Steam-teste", steam: true, running: true),
        ])
        #expect(found == .steamRunning(bottleName: "Steam-teste", bottleID: other))
    }

    @Test func steamInAStoppedBottleDoesNotBlock() {
        let target = UUID()
        #expect(BottleGuard.steamConflict(opening: target, bottles: [
            state(target, "Steam", steam: true, running: false),
            state(UUID(), "Steam-teste", steam: true, running: false),
        ]) == nil)
    }

    @Test func aBottleWithoutSteamIsNeverBlocked() {
        let target = UUID()
        #expect(BottleGuard.steamConflict(opening: target, bottles: [
            state(target, "Office", steam: false, running: false),
            state(UUID(), "Steam", steam: true, running: true),
        ]) == nil)
    }

    @Test func theTargetsOwnSteamDoesNotBlock() {
        let target = UUID()
        #expect(BottleGuard.steamConflict(opening: target, bottles: [
            state(target, "Steam", steam: true, running: true),
            state(UUID(), "Office", steam: false, running: true),
        ]) == nil)
    }
}

@Suite struct ProcessTerminatorTests {
    func start(_ script: String, output: Pipe? = nil) throws -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", script]
        process.standardOutput = output
        try process.run()
        return process
    }

    @Test func endsAProcessWithSIGTERM() async throws {
        let process = try start("exec sleep 30")
        #expect(await ProcessTerminator.end(process.processIdentifier, grace: .milliseconds(300)))
        process.waitUntilExit()
        #expect(process.terminationReason == .uncaughtSignal)
        #expect(process.terminationStatus == SIGTERM)
    }

    @Test func endsAProcessThatIgnoresSIGTERM() async throws {
        let pipe = Pipe()
        let process = try start("trap '' TERM; echo ready; while :; do sleep 1; done", output: pipe)
        // Wait until the shell has installed the trap, or SIGTERM could still end it within the grace period.
        var seen = Data()
        while !String(decoding: seen, as: UTF8.self).contains("ready") {
            let chunk = pipe.fileHandleForReading.availableData
            if chunk.isEmpty { break }
            seen.append(chunk)
        }
        #expect(String(decoding: seen, as: UTF8.self).contains("ready"))
        #expect(await ProcessTerminator.end(process.processIdentifier, grace: .milliseconds(300)))
        process.waitUntilExit()
        #expect(process.terminationStatus == SIGKILL)
    }

    @Test func aProcessThatAlreadyExitedCountsAsEnded() async throws {
        let process = try start("exit 0")
        process.waitUntilExit()
        #expect(await ProcessTerminator.end(process.processIdentifier, grace: .milliseconds(100)))
    }
}
