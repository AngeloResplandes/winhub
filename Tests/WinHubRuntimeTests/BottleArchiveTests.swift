import Foundation
import Testing
@testable import WinHubRuntime

@Suite struct BottleArchiveTests {
    /// A bottle like Wine makes them: a profile whose shell folders link to the Mac user's home.
    func makeBottle(in store: BottleStore, name: String = "Jogo", user: String, home: URL) throws -> Bottle {
        let bottle = try store.create(name: name, runtimeID: "w")
        let fm = FileManager.default
        let profile = bottle.driveC.appending(path: "users/\(user)")
        try fm.createDirectory(at: profile.appending(path: "AppData/Roaming/Game"), withIntermediateDirectories: true)
        try Data("save".utf8).write(to: profile.appending(path: "AppData/Roaming/Game/save.dat"))
        try fm.createSymbolicLink(atPath: profile.appending(path: "Desktop").path, withDestinationPath: home.appending(path: "Desktop").path)
        try fm.createSymbolicLink(atPath: profile.appending(path: "Videos").path, withDestinationPath: home.appending(path: "Movies").path)
        let dosdevices = bottle.prefix.appending(path: "dosdevices")
        try fm.createDirectory(at: dosdevices, withIntermediateDirectories: true)
        try fm.createSymbolicLink(atPath: dosdevices.appending(path: "c:").path, withDestinationPath: "../drive_c")
        try fm.createSymbolicLink(atPath: dosdevices.appending(path: "z:").path, withDestinationPath: "/")
        try Data("REGEDIT4".utf8).write(to: bottle.prefix.appending(path: "system.reg"))
        try fm.createDirectory(at: bottle.logs, withIntermediateDirectories: true)
        try Data("log".utf8).write(to: bottle.logs.appending(path: "steam.log"))
        var updated = bottle
        updated.msync = true
        try store.save(updated)
        return updated
    }

    func link(_ url: URL) -> String? { try? FileManager.default.destinationOfSymbolicLink(atPath: url.path) }

    @Test func roundTripMakesANewBottleForThisMac() async throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let oldHome = dir.appending(path: "Users/ana"), newHome = dir.appending(path: "Users/bia")
        let source = BottleStore(root: dir.appending(path: "A"))
        let original = try makeBottle(in: source, user: "ana", home: oldHome)
        let archive = dir.appending(path: "Jogo.winhubbottle")

        try await BottleArchive.export(original, to: archive)
        #expect(FileManager.default.fileExists(atPath: archive.path))

        let target = BottleStore(root: dir.appending(path: "B"))
        try FileManager.default.createDirectory(at: target.root, withIntermediateDirectories: true)
        let imported = try await BottleArchive.importBottle(from: archive, into: target, home: newHome, userName: "bia")
        #expect(imported.id != original.id)
        #expect(imported.name == "Jogo")
        #expect(imported.msync)
        #expect(try target.list().map(\.id) == [imported.id])

        let users = imported.driveC.appending(path: "users")
        // The saved data is there for both profiles; the links point to this Mac's home.
        for user in ["ana", "bia"] {
            #expect(try String(contentsOf: users.appending(path: "\(user)/AppData/Roaming/Game/save.dat"), encoding: .utf8) == "save")
            #expect(link(users.appending(path: "\(user)/Desktop")) == newHome.appending(path: "Desktop").path)
            #expect(link(users.appending(path: "\(user)/Videos")) == newHome.appending(path: "Movies").path)
        }
        #expect(link(imported.prefix.appending(path: "dosdevices/c:")) == "../drive_c")
        #expect(link(imported.prefix.appending(path: "dosdevices/z:")) == "/")
        #expect(!FileManager.default.fileExists(atPath: imported.logs.appending(path: "steam.log").path))
        // Nothing is left behind in the store's folder.
        #expect(try FileManager.default.contentsOfDirectory(atPath: target.root.path) == [imported.folder.lastPathComponent])
    }

    @Test func importLeavesTheSessionRecordBehind() async throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let home = dir.appending(path: "Users/ana")
        let source = BottleStore(root: dir.appending(path: "A"))
        let original = try makeBottle(in: source, user: "ana", home: home)
        try BottleSession.write(BottleSession(pid: 42, appPath: "/Applications/WinHub.app/Contents/MacOS/WinHub"),
                                to: original)
        let archive = dir.appending(path: "Jogo.winhubbottle")
        try await BottleArchive.export(original, to: archive)

        let target = BottleStore(root: dir.appending(path: "B"))
        try FileManager.default.createDirectory(at: target.root, withIntermediateDirectories: true)
        let imported = try await BottleArchive.importBottle(from: archive, into: target, home: home, userName: "ana")
        #expect(BottleSession.read(imported) == nil)
    }

    @Test func exportLeavesTheLogsAndTheSessionRecordOut() async throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = BottleStore(root: dir.appending(path: "A"))
        let bottle = try makeBottle(in: store, user: "ana", home: dir.appending(path: "Users/ana"))
        try BottleSession.write(BottleSession(pid: 42, appPath: "/Applications/WinHub.app/Contents/MacOS/WinHub"), to: bottle)
        let archive = dir.appending(path: "Jogo.winhubbottle")
        try await BottleArchive.export(bottle, to: archive)

        let unpacked = dir.appending(path: "unpacked")
        _ = try ProcessRunner.run(URL(fileURLWithPath: "/usr/bin/ditto"), arguments: ["-x", "-k", archive.path, unpacked.path])
        let folder = unpacked.appending(path: bottle.folder.lastPathComponent)
        let fm = FileManager.default
        #expect(fm.fileExists(atPath: folder.appending(path: BottleStore.fileName).path))
        #expect(fm.fileExists(atPath: folder.appending(path: "prefix/system.reg").path))
        #expect(!fm.fileExists(atPath: folder.appending(path: "logs").path))
        #expect(!fm.fileExists(atPath: folder.appending(path: "session.json").path))
        // The bottle itself keeps them, and no copy is left next to it.
        #expect(fm.fileExists(atPath: bottle.logs.appending(path: "steam.log").path))
        #expect(BottleSession.read(bottle) != nil)
        #expect(try fm.contentsOfDirectory(atPath: store.root.path) == [bottle.folder.lastPathComponent])
    }

    @Test func importingNextToTheOriginalGetsAnotherName() async throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let home = dir.appending(path: "Users/ana")
        let store = BottleStore(root: dir.appending(path: "A"))
        let original = try makeBottle(in: store, name: "Steam", user: "ana", home: home)
        let archive = dir.appending(path: "Steam.winhubbottle")
        try await BottleArchive.export(original, to: archive)

        let first = try await BottleArchive.importBottle(from: archive, into: store, home: home, userName: "ana")
        let second = try await BottleArchive.importBottle(from: archive, into: store, home: home, userName: "ana")
        #expect(first.name == "Steam (2)")
        #expect(second.name == "Steam (3)")
        #expect(Set(store.list().map(\.id)).count == 3)
        // Same user: no second profile.
        let users = try FileManager.default.contentsOfDirectory(atPath: first.driveC.appending(path: "users").path)
        #expect(users == ["ana"])
    }

    @Test func importReportsTheNameTheBottleHadBeforeRenaming() async throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let home = dir.appending(path: "Users/ana")
        let source = BottleStore(root: dir.appending(path: "A"))
        let original = try makeBottle(in: source, name: "Steam", user: "ana", home: home)
        let archive = dir.appending(path: "Steam.winhubbottle")
        try await BottleArchive.export(original, to: archive)

        // A store that has no "Steam" yet keeps the name; the next import in it is renamed.
        let target = BottleStore(root: dir.appending(path: "B"))
        try FileManager.default.createDirectory(at: target.root, withIntermediateDirectories: true)
        let first = try await BottleArchive.importBottleKeepingName(from: archive, into: target, home: home, userName: "ana")
        let second = try await BottleArchive.importBottleKeepingName(from: archive, into: target, home: home, userName: "ana")
        #expect(first.originalName == "Steam")
        #expect(first.bottle.name == "Steam")
        #expect(second.originalName == "Steam")
        #expect(second.bottle.name == "Steam (2)")
    }

    @Test func rejectsFilesThatAreNotBottles() async throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = BottleStore(root: dir.appending(path: "A"))
        try FileManager.default.createDirectory(at: store.root, withIntermediateDirectories: true)
        let junk = dir.appending(path: "junk.winhubbottle")
        try Data("not a zip".utf8).write(to: junk)
        await #expect(throws: BottleArchiveError.invalidArchive) {
            try await BottleArchive.importBottle(from: junk, into: store, home: dir, userName: "x")
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: store.root.path).isEmpty)
    }

    @Test func uniqueNamesIgnoreCase() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = BottleStore(root: dir)
        #expect(store.uniqueName("Steam") == "Steam")
        _ = try store.create(name: "Steam", runtimeID: "w")
        _ = try store.create(name: "steam (2)", runtimeID: "w")
        #expect(store.uniqueName("STEAM") == "STEAM (3)")
    }
}
