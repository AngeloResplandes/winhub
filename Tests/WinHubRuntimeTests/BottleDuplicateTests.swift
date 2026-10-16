import Foundation
import Testing
@testable import WinHubRuntime

@Suite struct BottleDuplicateTests {
    func write(_ text: String, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(text.utf8).write(to: url)
    }

    /// A bottle with a program file, a log, a session record and compat rules, with non-default settings.
    func makeBottle(in store: BottleStore) throws -> Bottle {
        var bottle = try store.create(name: "Jogos", runtimeID: "w", windowsVersion: .win7, graphics: .dxvk)
        try write("a", to: bottle.driveC.appending(path: "a.txt"))
        try write("log", to: bottle.logs.appending(path: "x.log"))
        try write("{}", to: BottleSession.url(for: bottle))
        try write("[]", to: CompatRules.url(for: bottle))
        bottle.msync = true
        bottle.environment = ["FOO": "1"]
        bottle.dllOverrides = ["d3d11": "n,b"]
        try store.save(bottle)
        return bottle
    }

    @Test func duplicateClonesTheBottleUnderANewIdentity() async throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = BottleStore(root: dir)
        let original = try makeBottle(in: store)

        let copy = try await store.duplicate(original, name: "  Jogos 2 ")
        let fm = FileManager.default
        #expect(copy.id != original.id)
        #expect(copy.name == "Jogos 2")
        #expect(copy.folder.lastPathComponent == BottleStore.folderName(for: "Jogos 2", id: copy.id))
        #expect(copy.folder.deletingLastPathComponent().standardizedFileURL == dir.standardizedFileURL)
        #expect(try String(contentsOf: copy.driveC.appending(path: "a.txt"), encoding: .utf8) == "a")
        #expect(!fm.fileExists(atPath: copy.logs.path))
        #expect(!fm.fileExists(atPath: BottleSession.url(for: copy).path))
        #expect(fm.fileExists(atPath: CompatRules.url(for: copy).path))
        #expect(copy.createdAt >= original.createdAt)

        // What the disk says, not only what was returned.
        let saved = try #require(store.list().first { $0.id == copy.id })
        #expect(saved.name == "Jogos 2")
        #expect(saved.graphics == .dxvk)
        #expect(saved.windowsVersion == .win7)
        #expect(saved.msync)
        #expect(saved.environment == ["FOO": "1"])
        #expect(saved.dllOverrides == ["d3d11": "n,b"])
        #expect(saved.runtimeID == "w")

        // The original is untouched.
        let kept = try #require(store.list().first { $0.id == original.id })
        #expect(kept.name == "Jogos")
        #expect(fm.fileExists(atPath: original.logs.appending(path: "x.log").path))
        #expect(fm.fileExists(atPath: BottleSession.url(for: original).path))
        #expect(store.list().count == 2)
    }

    @Test func duplicateRejectsEmptyAndTakenNames() async throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = BottleStore(root: dir)
        let original = try makeBottle(in: store)

        await #expect(throws: BottleError.invalidName) { try await store.duplicate(original, name: "   ") }
        await #expect(throws: BottleError.nameTaken("jogos")) { try await store.duplicate(original, name: "jogos") }
        #expect(store.list().count == 1)
        #expect(try FileManager.default.contentsOfDirectory(atPath: dir.path).count == 1)
    }

    @Test func failedCloneLeavesNoFolderBehind() async throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = BottleStore(root: dir)
        var ghost = try makeBottle(in: store)
        ghost.folder = dir.appending(path: "missing")

        await #expect(throws: (any Error).self) { try await store.duplicate(ghost, name: "Outra") }
        #expect(store.list().map(\.name) == ["Jogos"])
        #expect(try FileManager.default.contentsOfDirectory(atPath: dir.path).count == 1)
    }
}
