import Foundation

public enum BottleArchiveError: Error, LocalizedError, Equatable {
    case invalidArchive
    case failed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidArchive: String(localized: "O arquivo não é uma garrafa exportada pelo WinHub.")
        case .failed(let output): String(localized: "Não foi possível criar o arquivo da garrafa. \(output)")
        }
    }
}

/// A bottle in one file (`.winhubbottle`, a zip made by `ditto`), to back it up or take it to another Mac.
///
/// The folder goes as it is, symbolic links included (never followed, so the Mac user's own folders stay out),
/// except its logs and its session record.
/// Importing makes a new bottle: a new id (shortcuts and the running state are keyed by it), a free name, and
/// the profile's shell folders (Desktop, Documents…) pointed at this Mac's home. Close the bottle before exporting.
public enum BottleArchive {
    public static let fileExtension = "winhubbottle"

    public static func export(_ bottle: Bottle, to destination: URL) async throws {
        let fm = FileManager.default
        try? fm.removeItem(at: destination)
        // An APFS clone (instant, no extra space) without the logs and the record of which WinHub used it.
        let staging = bottle.folder.deletingLastPathComponent()
            .appending(path: ".export-\(UUID().uuidString)", directoryHint: .isDirectory)
        try fm.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: staging) }
        let copy = staging.appending(path: bottle.folder.lastPathComponent, directoryHint: .isDirectory)
        let clone = try await run("/bin/cp", ["-cR", bottle.folder.path, copy.path])
        guard clone.status == 0 else { throw BottleArchiveError.failed(clone.output) }
        try? fm.removeItem(at: copy.appending(path: "logs"))
        try? fm.removeItem(at: copy.appending(path: BottleSession.fileName))

        let result = try await ditto(["-c", "-k", "--sequesterRsrc", "--keepParent", copy.path, destination.path])
        guard result.status == 0 else { throw BottleArchiveError.failed(result.output) }
    }

    /// `home` and `userName`: this Mac's user, whose profile Wine uses (`C:\users\<userName>`).
    public static func importBottle(from archive: URL, into store: BottleStore,
                                    home: URL = FileManager.default.homeDirectoryForCurrentUser,
                                    userName: String = NSUserName()) async throws -> Bottle {
        try await importBottleKeepingName(from: archive, into: store, home: home, userName: userName).bottle
    }

    /// Like `importBottle`, also returning the name the bottle had in the archive (before a free one was picked).
    public static func importBottleKeepingName(from archive: URL, into store: BottleStore,
                                               home: URL = FileManager.default.homeDirectoryForCurrentUser,
                                               userName: String = NSUserName()) async throws
        -> (bottle: Bottle, originalName: String) {
        let fm = FileManager.default
        // Unpacked next to the bottles, so moving it into place is instant.
        let temporary = store.root.appending(path: ".import-\(UUID().uuidString)", directoryHint: .isDirectory)
        try fm.createDirectory(at: temporary, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: temporary) }

        let result = try await ditto(["-x", "-k", archive.path, temporary.path])
        guard result.status == 0,
              let folder = try? fm.contentsOfDirectory(at: temporary, includingPropertiesForKeys: nil)
                .first(where: { fm.fileExists(atPath: $0.appending(path: BottleStore.fileName).path) }),
              var bottle = try? store.load(folder: folder) else { throw BottleArchiveError.invalidArchive }

        bottle.id = UUID()
        let originalName = bottle.name
        bottle.name = store.uniqueName(bottle.name)
        let destination = store.root.appending(path: BottleStore.folderName(for: bottle.name, id: bottle.id),
                                               directoryHint: .isDirectory)
        try fm.moveItem(at: folder, to: destination)
        bottle.folder = destination
        try? fm.removeItem(at: bottle.logs)
        // Names a WinHub process of the Mac (or the moment) the bottle came from.
        try? fm.removeItem(at: BottleSession.url(for: bottle))
        adoptProfile(in: bottle, home: home, userName: userName)
        try store.save(bottle)
        return (bottle, originalName)
    }

    /// Big bottles take a while; never on the caller's thread (it may be the main one).
    private static func ditto(_ arguments: [String]) async throws -> ProcessRunner.Result {
        try await run("/usr/bin/ditto", arguments)
    }

    private static func run(_ tool: String, _ arguments: [String]) async throws -> ProcessRunner.Result {
        try await Task.detached(priority: .userInitiated) {
            try ProcessRunner.run(URL(fileURLWithPath: tool), arguments: arguments)
        }.value
    }

    /// Wine keeps the Windows profile in `C:\users\<Mac user>`. Another user gets a clone of the bottle's
    /// profile (the registry still names the old one, so it stays too), and every profile's shell folder links
    /// point into `home`, where Wine made them point on the original Mac.
    static func adoptProfile(in bottle: Bottle, home: URL, userName: String) {
        let fm = FileManager.default
        let users = bottle.driveC.appending(path: "users", directoryHint: .isDirectory)
        var profiles = ((try? fm.contentsOfDirectory(atPath: users.path)) ?? []).filter { $0 != "Public" }
        if !profiles.contains(userName), profiles.count == 1,
           (try? fm.copyItem(at: users.appending(path: profiles[0]), to: users.appending(path: userName))) != nil {
            profiles.append(userName)
        }
        for profile in profiles {
            let folder = users.appending(path: profile, directoryHint: .isDirectory)
            for item in (try? fm.contentsOfDirectory(atPath: folder.path)) ?? [] {
                let path = folder.appending(path: item).path
                guard let target = try? fm.destinationOfSymbolicLink(atPath: path),
                      target.hasPrefix("/"), target != "/", !target.hasPrefix(bottle.folder.path + "/") else { continue }
                let newTarget = home.appending(path: URL(fileURLWithPath: target).lastPathComponent).path
                guard newTarget != target else { continue }
                try? fm.removeItem(atPath: path)
                try? fm.createSymbolicLink(atPath: path, withDestinationPath: newTarget)
            }
        }
    }
}
