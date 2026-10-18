import Foundation

public enum AppLauncherError: Error, LocalizedError, Equatable {
    case folderExists(String)

    public var errorDescription: String? {
        switch self {
        case .folderExists(let name):
            String(localized: "Já existe uma pasta de atalhos chamada “\(name)” em Aplicativos/WinHub. Mude ou remova essa pasta e tente de novo.")
        }
    }
}

/// Creates small `.app` bundles that open a Windows program from Finder,
/// Spotlight or the Dock.
///
/// Each bundle is `<root>/<bottle>/<program>.app` whose executable is a shell
/// script that asks WinHub to open the program (`winhub://open?…`) and exits.
/// Running Wine from inside the launcher's own process does not work: programs
/// started that way stall (Steam's bootstrapper never finishes), while the same
/// command started by WinHub runs normally.
public struct AppLauncherBuilder: Sendable {
    public let root: URL

    public init(root: URL) {
        self.root = root
    }

    public static var defaultRoot: URL {
        FileManager.default.homeDirectoryForCurrentUser.appending(path: "Applications/WinHub", directoryHint: .isDirectory)
    }

    public func folder(for bottle: Bottle) -> URL {
        root.appending(path: Self.safeName(bottle.name), directoryHint: .isDirectory)
    }

    public func launcherURL(for program: InstalledProgram, in bottle: Bottle) -> URL {
        folder(for: bottle).appending(path: "\(Self.safeName(program.name)).app", directoryHint: .isDirectory)
    }

    public func exists(for program: InstalledProgram, in bottle: Bottle) -> Bool {
        FileManager.default.fileExists(atPath: launcherURL(for: program, in: bottle).path)
    }

    @discardableResult
    public func create(for program: InstalledProgram, in bottle: Bottle) throws -> URL {
        let app = launcherURL(for: program, in: bottle)
        let macOS = app.appending(path: "Contents/MacOS", directoryHint: .isDirectory)
        try? FileManager.default.removeItem(at: app)
        try FileManager.default.createDirectory(at: macOS, withIntermediateDirectories: true)

        let info: [String: Any] = [
            "CFBundleName": program.name,
            "CFBundleDisplayName": program.name,
            "CFBundleIdentifier": "io.github.winhub.launcher.\(Self.identifier(bottle.id.uuidString + "." + program.name))",
            "CFBundleExecutable": "launcher",
            "CFBundlePackageType": "APPL",
            "CFBundleShortVersionString": "1.0",
            "CFBundleVersion": "1",
            "LSMinimumSystemVersion": "14.0",
            "NSHighResolutionCapable": true,
            // The script only forwards to WinHub; no Dock icon of its own.
            "LSUIElement": true,
            "WinHubBottleID": bottle.id.uuidString,
            "WinHubShortcut": program.shortcut.path,
        ]
        let plist = try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
        try plist.write(to: app.appending(path: "Contents/Info.plist"))

        let script = macOS.appending(path: "launcher")
        try Self.script(for: program, in: bottle).write(to: script, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)
        return app
    }

    /// Removes every launcher of a bottle (used when the bottle is deleted).
    public func removeAll(for bottle: Bottle) throws {
        let dir = folder(for: bottle)
        if FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.removeItem(at: dir)
        }
    }

    /// Moves the shortcuts folder of a renamed bottle (`<root>/<old>` to `<root>/<new>`). The scripts hold the
    /// bottle's id and the `.lnk` path, which do not change. The destination is never overwritten or shared:
    /// another folder there throws `AppLauncherError.folderExists`, even when the bottle has no shortcuts yet
    /// (its next shortcuts would land among the other folder's). Returns whether something moved.
    @discardableResult
    public func renameFolder(from oldName: String, to newName: String) throws -> Bool {
        let oldFolder = root.appending(path: Self.safeName(oldName), directoryHint: .isDirectory)
        let newFolder = root.appending(path: Self.safeName(newName), directoryHint: .isDirectory)
        let fm = FileManager.default
        guard oldFolder.lastPathComponent != newFolder.lastPathComponent else { return false }
        // On a case-insensitive volume a case-only rename finds the source itself at the destination.
        let caseOnly = fm.fileExists(atPath: newFolder.path) && Self.isSameItem(oldFolder, newFolder)
        if fm.fileExists(atPath: newFolder.path), !caseOnly {
            throw AppLauncherError.folderExists(newFolder.lastPathComponent)
        }
        guard fm.fileExists(atPath: oldFolder.path) else { return false }
        if caseOnly {
            let hop = root.appending(path: ".rename-\(UUID().uuidString)", directoryHint: .isDirectory)
            try fm.moveItem(at: oldFolder, to: hop)
            do {
                try fm.moveItem(at: hop, to: newFolder)
            } catch {
                try? fm.moveItem(at: hop, to: oldFolder)
                throw error
            }
            return true
        }
        try fm.moveItem(at: oldFolder, to: newFolder)
        return true
    }

    private static func isSameItem(_ a: URL, _ b: URL) -> Bool {
        guard let first = try? a.resourceValues(forKeys: [.fileResourceIdentifierKey]).fileResourceIdentifier,
              let second = try? b.resourceValues(forKeys: [.fileResourceIdentifierKey]).fileResourceIdentifier else { return false }
        return first.isEqual(second)
    }

    static func script(for program: InstalledProgram, in bottle: Bottle) -> String {
        """
        #!/bin/sh
        # Criado pelo WinHub: abre “\(program.name)” na garrafa “\(bottle.name)”.
        exec /usr/bin/open \(shellQuote(openURL(for: program, in: bottle).absoluteString))

        """
    }

    /// `winhub://open?bottle=<uuid>&shortcut=<path>`, handled by the WinHub app.
    public static func openURL(for program: InstalledProgram, in bottle: Bottle) -> URL {
        var components = URLComponents()
        components.scheme = "winhub"
        components.host = "open"
        components.queryItems = [
            URLQueryItem(name: "bottle", value: bottle.id.uuidString),
            URLQueryItem(name: "shortcut", value: program.shortcut.path),
        ]
        // Encode "+" too, so the path survives form-style decoding.
        components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        return components.url!
    }

    /// Single-quotes a value for `/bin/sh`.
    static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    /// File-system-safe name that keeps accents and spaces.
    static func safeName(_ name: String) -> String {
        let cleaned = name.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "Programa" : cleaned
    }

    static func identifier(_ value: String) -> String {
        value.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) && $0.isASCII ? String($0) : "-" }.joined()
    }
}
