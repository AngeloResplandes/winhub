import Foundation

/// Why this WinHub must not run Wine in a bottle right now.
public enum BottleConflict: Equatable, Sendable {
    /// Another WinHub that is still open runs programs in the bottle.
    case otherWinHub(appPath: String)
    /// The bottle's programs run under another engine's wineserver.
    case otherEngine(wineserver: String)
    /// Steam is open in another bottle.
    case steamRunning(bottleName: String, bottleID: UUID)
}

/// Decides whether this WinHub may run Wine in a bottle. Every copy of WinHub shares the bottles: on
/// 2026-10-13 the installed one and a development build used the Steam bottle together, and on 2026-10-11
/// two bottles ran Steam at once; both times Steam uninstalled games. Pure: `WineStore` gathers the state.
public enum BottleGuard {
    /// - Parameters:
    ///   - serverPath: executable of the bottle's live wineserver; `nil` when the bottle is not running.
    ///   - ownWineserver: the `wineserver` of this WinHub's engine.
    ///   - sessionExecutable: executable of the process with `session.pid` now; `nil` when it has exited.
    public static func conflict(serverPath: String?, ownWineserver: String, session: BottleSession?,
                                sessionExecutable: String?, ownPID: pid_t) -> BottleConflict? {
        guard let serverPath else { return nil }
        // Pids are reused, so the record counts only while its pid is still that WinHub.
        if let session, session.pid != ownPID, let sessionExecutable,
           normalized(sessionExecutable) == normalized(session.appPath) {
            return .otherWinHub(appPath: session.appPath)
        }
        guard normalized(serverPath) == normalized(ownWineserver) else { return .otherEngine(wineserver: serverPath) }
        return nil
    }

    /// One bottle, as `steamConflict` sees it.
    public struct BottleState: Sendable {
        public var id: UUID
        public var name: String
        public var hasSteam: Bool
        public var isRunning: Bool

        public init(id: UUID, name: String, hasSteam: Bool, isRunning: Bool) {
            self.id = id
            self.name = name
            self.hasSteam = hasSteam
            self.isRunning = isRunning
        }
    }

    /// Opening a program in a bottle with Steam while another bottle with Steam runs. Steam is counted by
    /// its files, not its process: a game opened from its own shortcut starts Steam too.
    public static func steamConflict(opening bottleID: UUID, bottles: [BottleState]) -> BottleConflict? {
        guard bottles.first(where: { $0.id == bottleID })?.hasSteam == true,
              let other = bottles.first(where: { $0.id != bottleID && $0.hasSteam && $0.isRunning }) else { return nil }
        return .steamRunning(bottleName: other.name, bottleID: other.id)
    }

    /// The kernel reports `/private/tmp/…` where a path says `/tmp/…`.
    static func normalized(_ path: String) -> String {
        let resolved = URL(fileURLWithPath: path).resolvingSymlinksInPath().standardizedFileURL.path
        for root in ["/private/tmp/", "/private/var/", "/private/etc/"] where resolved.hasPrefix(root) {
            return String(resolved.dropFirst("/private".count))
        }
        return resolved
    }
}
