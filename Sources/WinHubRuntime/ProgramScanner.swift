import Foundation

/// A program installed in a bottle, found through its Start Menu or Desktop shortcut.
public struct InstalledProgram: Sendable, Hashable, Identifiable {
    public var name: String
    public var shortcut: URL
    public var id: String { shortcut.path }

    public init(name: String, shortcut: URL) {
        self.name = name
        self.shortcut = shortcut
    }
}

/// Finds `.lnk` shortcuts that Windows installers create.
public enum ProgramScanner {
    /// Folders scanned, relative to `drive_c`. `*` stands for each user folder.
    static let locations = [
        "ProgramData/Microsoft/Windows/Start Menu/Programs",
        "users/*/AppData/Roaming/Microsoft/Windows/Start Menu/Programs",
        "users/Public/Desktop",
        "users/*/Desktop",
    ]

    /// Shortcuts that are not programs to launch.
    static let ignoredWords = ["uninstall", "desinstalar", "readme", "leia-me", "help", "ajuda", "support", "website"]

    public static func programs(in bottle: Bottle) -> [InstalledProgram] {
        programs(driveC: bottle.driveC)
    }

    public static func programs(driveC: URL) -> [InstalledProgram] {
        var seen = Set<String>()
        var found: [InstalledProgram] = []
        for folder in expand(locations, in: driveC) {
            guard let walker = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: nil) else { continue }
            for case let file as URL in walker where file.pathExtension.lowercased() == "lnk" {
                let name = file.deletingPathExtension().lastPathComponent
                let lowered = name.lowercased()
                guard !ignoredWords.contains(where: lowered.contains), seen.insert(lowered).inserted else { continue }
                found.append(InstalledProgram(name: name, shortcut: file))
            }
        }
        return found.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    static func expand(_ patterns: [String], in driveC: URL) -> [URL] {
        let users = (try? FileManager.default.contentsOfDirectory(atPath: driveC.appending(path: "users").path)) ?? []
        return patterns.flatMap { pattern -> [URL] in
            guard pattern.contains("*") else { return [driveC.appending(path: pattern)] }
            return users.map { driveC.appending(path: pattern.replacingOccurrences(of: "*", with: $0)) }
        }
    }
}
