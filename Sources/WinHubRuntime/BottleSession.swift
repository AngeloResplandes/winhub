import Foundation

/// Which WinHub last ran Wine in a bottle, kept as `<bottle>/session.json`. Every copy of WinHub (the
/// installed one, a development build) shares the same bottles; this record lets one see that another
/// is using a bottle (see `BottleGuard`).
public struct BottleSession: Codable, Equatable, Sendable {
    public var pid: pid_t
    /// That WinHub's executable, as `WineServerStatus.executablePath` reports it.
    public var appPath: String
    public var startedAt: Date

    public init(pid: pid_t, appPath: String, startedAt: Date = .now) {
        self.pid = pid
        self.appPath = appPath
        self.startedAt = startedAt
    }

    enum CodingKeys: String, CodingKey { case pid, appPath, startedAt }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        pid = try c.decode(pid_t.self, forKey: .pid)
        appPath = try c.decode(String.self, forKey: .appPath)
        startedAt = try c.decodeIfPresent(Date.self, forKey: .startedAt) ?? .distantPast
    }

    static let fileName = "session.json"

    static func url(for bottle: Bottle) -> URL { bottle.folder.appending(path: fileName) }

    /// This process.
    public static var current: BottleSession {
        let pid = getpid()
        return BottleSession(pid: pid, appPath: WineServerStatus.executablePath(pid: pid) ?? Bundle.main.executablePath ?? "")
    }

    /// `nil` when missing or unreadable: a broken record never blocks a bottle.
    public static func read(_ bottle: Bottle) -> BottleSession? {
        guard let data = try? Data(contentsOf: url(for: bottle)) else { return nil }
        return try? decoder.decode(BottleSession.self, from: data)
    }

    public static func write(_ session: BottleSession, to bottle: Bottle) throws {
        try encoder.encode(session).write(to: url(for: bottle), options: .atomic)
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
