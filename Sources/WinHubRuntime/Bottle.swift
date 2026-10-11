import Foundation

/// A Wine prefix plus WinHub's settings for it, stored as
/// `<bottles>/<folder>/bottle.json` with the prefix in `<folder>/prefix/`.
public struct Bottle: Codable, Sendable, Identifiable, Hashable {
    public enum WindowsVersion: String, Codable, Sendable, CaseIterable {
        case win11, win10, win81, win7, winxp

        public var title: String {
            switch self {
            case .win11: "Windows 11"
            case .win10: "Windows 10"
            case .win81: "Windows 8.1"
            case .win7: "Windows 7"
            case .winxp: "Windows XP"
            }
        }
    }

    public var id: UUID
    public var name: String
    public var runtimeID: String
    public var windowsVersion: WindowsVersion
    /// Extra variables for every process in the bottle.
    public var environment: [String: String]
    /// `WINEDLLOVERRIDES` entries, e.g. `["d3d11": "n,b"]`.
    public var dllOverrides: [String: String]
    public var graphics: GraphicsBackend
    /// Use msync for Wine's synchronization (only with a runtime built with it).
    public var msync: Bool
    /// Show Metal's performance HUD (and DXVK's, with DXVK) in games.
    public var performanceHUD: Bool
    public var createdAt: Date

    /// Folder of this bottle; set when it is loaded, not stored in the JSON.
    public internal(set) var folder: URL = URL(fileURLWithPath: "/")

    enum CodingKeys: String, CodingKey {
        case id, name, runtimeID, windowsVersion, environment, dllOverrides, graphics, msync, performanceHUD, createdAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        runtimeID = try c.decode(String.self, forKey: .runtimeID)
        windowsVersion = try c.decodeIfPresent(WindowsVersion.self, forKey: .windowsVersion) ?? .win10
        environment = try c.decodeIfPresent([String: String].self, forKey: .environment) ?? [:]
        dllOverrides = try c.decodeIfPresent([String: String].self, forKey: .dllOverrides) ?? [:]
        // A backend from a newer WinHub must not make the bottle unreadable.
        graphics = (try? c.decodeIfPresent(GraphicsBackend.self, forKey: .graphics)) ?? .wined3d
        msync = try c.decodeIfPresent(Bool.self, forKey: .msync) ?? false
        performanceHUD = try c.decodeIfPresent(Bool.self, forKey: .performanceHUD) ?? false
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now
    }

    public init(id: UUID = UUID(), name: String, runtimeID: String, windowsVersion: WindowsVersion = .win10,
                environment: [String: String] = [:], dllOverrides: [String: String] = [:],
                graphics: GraphicsBackend = .wined3d, msync: Bool = false, performanceHUD: Bool = false,
                createdAt: Date = .now) {
        self.id = id
        self.name = name
        self.runtimeID = runtimeID
        self.windowsVersion = windowsVersion
        self.environment = environment
        self.dllOverrides = dllOverrides
        self.graphics = graphics
        self.msync = msync
        self.performanceHUD = performanceHUD
        self.createdAt = createdAt
    }

    public var prefix: URL { folder.appending(path: "prefix", directoryHint: .isDirectory) }
    public var driveC: URL { prefix.appending(path: "drive_c", directoryHint: .isDirectory) }
    public var logs: URL { folder.appending(path: "logs", directoryHint: .isDirectory) }
    /// `wineboot --init` has completed for this prefix.
    public var isInitialized: Bool { FileManager.default.fileExists(atPath: prefix.appending(path: "system.reg").path) }

    /// Mac location of a `C:\…` path inside this bottle, or `nil` for other drives.
    public func unixPath(forWindowsPath path: String) -> URL? {
        let normalized = path.replacingOccurrences(of: "\\", with: "/")
        guard normalized.count >= 2, normalized.prefix(2).lowercased() == "c:" else { return nil }
        let relative = normalized.dropFirst(2).split(separator: "/").joined(separator: "/")
        return relative.isEmpty ? driveC : driveC.appending(path: relative)
    }
}

public enum BottleError: Error, LocalizedError, Equatable {
    case nameTaken(String)
    case invalidName

    public var errorDescription: String? {
        switch self {
        case .nameTaken(let name): "Já existe uma garrafa chamada “\(name)”."
        case .invalidName: "Dê um nome à garrafa."
        }
    }
}

/// Creates, lists and deletes bottles under `root`.
public struct BottleStore: Sendable {
    public let root: URL

    public init(root: URL) {
        self.root = root
    }

    public static var defaultRoot: URL {
        URL.applicationSupportDirectory.appending(path: "WinHub/Bottles", directoryHint: .isDirectory)
    }

    static let fileName = "bottle.json"

    public func list() -> [Bottle] {
        let folders = (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
        return folders.compactMap { try? load(folder: $0) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    public func load(folder: URL) throws -> Bottle {
        var bottle = try Self.decoder.decode(Bottle.self, from: Data(contentsOf: folder.appending(path: Self.fileName)))
        bottle.folder = folder
        return bottle
    }

    /// Writes the bottle's folder and `bottle.json`. The prefix is created later by `WineLauncher.initialize`.
    public func create(name: String, runtimeID: String, windowsVersion: Bottle.WindowsVersion = .win10) throws -> Bottle {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw BottleError.invalidName }
        guard !list().contains(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) else {
            throw BottleError.nameTaken(trimmed)
        }
        var bottle = Bottle(name: trimmed, runtimeID: runtimeID, windowsVersion: windowsVersion)
        bottle.folder = root.appending(path: Self.folderName(for: trimmed, id: bottle.id), directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: bottle.folder, withIntermediateDirectories: true)
        try save(bottle)
        return bottle
    }

    public func save(_ bottle: Bottle) throws {
        try Self.encoder.encode(bottle).write(to: bottle.folder.appending(path: Self.fileName), options: .atomic)
    }

    public func delete(_ bottle: Bottle) throws {
        try FileManager.default.removeItem(at: bottle.folder)
    }

    /// Folder names are ASCII and unique; the display name lives in `bottle.json`.
    static func folderName(for name: String, id: UUID) -> String {
        let ascii = name.folding(options: [.diacriticInsensitive, .widthInsensitive], locale: nil)
        let slug = ascii.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) && $0.isASCII ? String($0) : "-" }
            .joined()
            .split(separator: "-", omittingEmptySubsequences: true)
            .joined(separator: "-")
        return "\(slug.isEmpty ? "garrafa" : slug)-\(id.uuidString.prefix(8))"
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
