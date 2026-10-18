import Foundation
import Testing
@testable import WinHubRuntime

@Suite struct BottleRenameTests {
    func makeFolder(_ url: URL, file: String = "x.txt") throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        try Data("x".utf8).write(to: url.appending(path: file))
    }

    func names(in url: URL) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: url.path).sorted()
    }

    @Test func renameChangesOnlyTheNameKeepingIdAndFolder() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = BottleStore(root: dir)
        let original = try store.create(name: "Jogos", runtimeID: "w", windowsVersion: .win7)

        let renamed = try store.rename(original, to: "  Diversão ")
        #expect(renamed.name == "Diversão")
        #expect(renamed.id == original.id)
        #expect(renamed.folder == original.folder)
        #expect(renamed.windowsVersion == .win7)
        let listed = store.list()
        #expect(listed.map(\.name) == ["Diversão"])
        #expect(listed.first?.folder.lastPathComponent == original.folder.lastPathComponent)
    }

    @Test func renameRejectsEmptyAndTakenNames() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = BottleStore(root: dir)
        let first = try store.create(name: "Jogos", runtimeID: "w")
        _ = try store.create(name: "Trabalho", runtimeID: "w")

        #expect(throws: BottleError.invalidName) { try store.rename(first, to: "   ") }
        #expect(throws: BottleError.nameTaken("trabalho")) { try store.rename(first, to: "trabalho") }
        #expect(Set(store.list().map(\.name)) == ["Jogos", "Trabalho"])
    }

    @Test func renameAllowsTheSameNameWithAnotherCase() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = BottleStore(root: dir)
        let bottle = try store.create(name: "Jogos", runtimeID: "w")

        #expect(try store.rename(bottle, to: "jogos").name == "jogos")
        #expect(try store.rename(bottle, to: "Jogos").name == "Jogos")
        #expect(store.list().map(\.name) == ["Jogos"])
    }

    @Test func renameFolderMovesTheShortcutsAndToleratesAMissingFolder() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let builder = AppLauncherBuilder(root: dir)
        try makeFolder(dir.appending(path: "Jogos"), file: "Steam.app")

        try builder.renameFolder(from: "Jogos", to: "Diversão")
        #expect(try names(in: dir) == ["Diversão"])
        #expect(try names(in: dir.appending(path: "Diversão")) == ["Steam.app"])

        // Nothing to move, same folder after cleaning the name: both are no-ops.
        try builder.renameFolder(from: "Outra", to: "Nova")
        try builder.renameFolder(from: "A/B", to: "A-B")
        #expect(try names(in: dir) == ["Diversão"])
    }

    @Test func renameFolderHandlesACaseOnlyChange() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let builder = AppLauncherBuilder(root: dir)
        try makeFolder(dir.appending(path: "Jogos"))

        try builder.renameFolder(from: "Jogos", to: "jogos")
        #expect(try names(in: dir) == ["jogos"])
        #expect(try names(in: dir.appending(path: "jogos")) == ["x.txt"])
    }

    @Test func renameFolderRefusesToOverwriteAnExistingFolder() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let builder = AppLauncherBuilder(root: dir)
        try makeFolder(dir.appending(path: "Jogos"), file: "a.txt")
        try makeFolder(dir.appending(path: "Diversão"), file: "b.txt")

        #expect(throws: AppLauncherError.folderExists("Diversão")) { try builder.renameFolder(from: "Jogos", to: "Diversão") }
        #expect(try names(in: dir.appending(path: "Jogos")) == ["a.txt"])
        #expect(try names(in: dir.appending(path: "Diversão")) == ["b.txt"])
    }

    @Test func renameFolderRefusesATakenDestinationEvenWithoutShortcuts() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let builder = AppLauncherBuilder(root: dir)
        try makeFolder(dir.appending(path: "Diversão"), file: "b.txt")

        // "Jogos" has no shortcuts folder, but its next shortcuts would land among another folder's.
        #expect(throws: AppLauncherError.folderExists("Diversão")) { try builder.renameFolder(from: "Jogos", to: "Diversão") }
        #expect(try names(in: dir) == ["Diversão"])
        #expect(try names(in: dir.appending(path: "Diversão")) == ["b.txt"])
    }

    @Test func renameFolderSaysWhetherItMoved() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let builder = AppLauncherBuilder(root: dir)
        try makeFolder(dir.appending(path: "Jogos"))

        #expect(try builder.renameFolder(from: "Jogos", to: "Diversão"))
        #expect(try !builder.renameFolder(from: "Outra", to: "Nova"))
        #expect(try !builder.renameFolder(from: "A/B", to: "A-B"))
    }

    @Test func failedSaveMovesTheShortcutsBack() throws {
        let dir = try makeTempDirectory()
        let store = BottleStore(root: dir.appending(path: "Bottles"))
        let builder = AppLauncherBuilder(root: dir.appending(path: "Applications"))
        let bottle = try store.create(name: "Jogos", runtimeID: "w")
        try makeFolder(builder.folder(for: bottle), file: "Steam.app")
        // A read-only bottle folder makes the atomic write of bottle.json fail.
        let fm = FileManager.default
        try fm.setAttributes([.posixPermissions: 0o555], ofItemAtPath: bottle.folder.path)
        defer {
            try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: bottle.folder.path)
            try? fm.removeItem(at: dir)
        }

        #expect(throws: (any Error).self) { try store.rename(bottle, to: "Diversão", movingLaunchersWith: builder) }
        #expect(store.list().map(\.name) == ["Jogos"])
        #expect(try names(in: builder.root) == ["Jogos"])
        #expect(try names(in: builder.root.appending(path: "Jogos")) == ["Steam.app"])

        // Without shortcuts nothing moved, so nothing moves back either.
        try fm.removeItem(at: builder.root.appending(path: "Jogos"))
        #expect(throws: (any Error).self) { try store.rename(bottle, to: "Diversão", movingLaunchersWith: builder) }
        #expect(try names(in: builder.root).isEmpty)
    }

    @Test func renameWithLaunchersMovesThemAndKeepsTheBottleWhenTheMoveFails() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = BottleStore(root: dir.appending(path: "Bottles"))
        let builder = AppLauncherBuilder(root: dir.appending(path: "Applications"))
        let bottle = try store.create(name: "Jogos", runtimeID: "w")
        try makeFolder(builder.folder(for: bottle), file: "Steam.app")

        // The destination folder is taken: the bottle keeps its name and the shortcuts stay.
        try makeFolder(builder.root.appending(path: "Diversão"))
        #expect(throws: AppLauncherError.folderExists("Diversão")) {
            try store.rename(bottle, to: "Diversão", movingLaunchersWith: builder)
        }
        #expect(store.list().map(\.name) == ["Jogos"])
        #expect(try names(in: builder.root.appending(path: "Jogos")) == ["Steam.app"])

        try FileManager.default.removeItem(at: builder.root.appending(path: "Diversão"))
        let renamed = try store.rename(bottle, to: "Diversão", movingLaunchersWith: builder)
        #expect(store.list().map(\.name) == ["Diversão"])
        #expect(builder.folder(for: renamed).lastPathComponent == "Diversão")
        #expect(try names(in: builder.folder(for: renamed)) == ["Steam.app"])
        #expect(!FileManager.default.fileExists(atPath: builder.root.appending(path: "Jogos").path))
    }

    @Test func invalidRenameLeavesTheShortcutsAlone() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = BottleStore(root: dir.appending(path: "Bottles"))
        let builder = AppLauncherBuilder(root: dir.appending(path: "Applications"))
        let bottle = try store.create(name: "Jogos", runtimeID: "w")
        _ = try store.create(name: "Trabalho", runtimeID: "w")
        try makeFolder(builder.folder(for: bottle), file: "Steam.app")

        #expect(throws: BottleError.nameTaken("TRABALHO")) { try store.rename(bottle, to: "TRABALHO", movingLaunchersWith: builder) }
        #expect(throws: BottleError.invalidName) { try store.rename(bottle, to: " ", movingLaunchersWith: builder) }
        #expect(try names(in: builder.root) == ["Jogos"])
    }
}
