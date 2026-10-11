import Foundation

/// Keeps Steam's window from staying black on Wine 11 for macOS.
///
/// Steam's UI is Chromium (`steamwebhelper.exe`), which draws each window from a
/// separate GPU process. Wine's macOS driver does not show what one process draws
/// into another process's window, so the window stays black. WinHub's wrapper
/// (`Support/steamwebhelper-wrapper`) takes the helper's place and starts the
/// original, renamed `steamwebhelper_real.exe`, with `--in-process-gpu`.
///
/// Steam must be started with `-noverifyfiles` (`SteamClient.launchArguments`),
/// otherwise it restores the original helper on start.
public struct SteamWebHelperWrapper: Sendable {
    /// Windows build of the wrapper, shipped in the app's resources.
    public let wrapper: URL

    public init(wrapper: URL) {
        self.wrapper = wrapper
    }

    /// The wrapper in the app's resources (`bundled`) or, for `swift run`, the build
    /// named by `WINHUB_STEAMWEBHELPER_WRAPPER` (see `scripts/build-steam-wrapper.sh`).
    public static func locate(bundled: URL?,
                              environment: [String: String] = ProcessInfo.processInfo.environment) -> Self? {
        let dev = environment["WINHUB_STEAMWEBHELPER_WRAPPER"].map { URL(fileURLWithPath: $0) }
        return [bundled, dev].compactMap { $0 }
            .first { FileManager.default.fileExists(atPath: $0.path) }
            .map(Self.init)
    }

    static let folder = "Program Files (x86)/Steam/bin/cef/cef.win64"
    static let helperName = "steamwebhelper.exe"
    static let realName = "steamwebhelper_real.exe"

    /// Text embedded in every build of the wrapper, so that an older one is never
    /// mistaken for Steam's helper (it would then start itself in a loop).
    public static let marker = "WINHUB-STEAMWEBHELPER-WRAPPER"

    /// Puts the wrapper in place, again after Steam updates its helper. Call it only
    /// before starting Steam: while Steam runs, a swap is undone when Steam restarts.
    /// Returns `false` when the wrapper is not in place afterwards (no Steam helper to wrap).
    @discardableResult
    public func install(in bottle: Bottle) throws -> Bool {
        let fm = FileManager.default
        let cef = bottle.driveC.appending(path: Self.folder, directoryHint: .isDirectory)
        let helper = cef.appending(path: Self.helperName)
        let real = cef.appending(path: Self.realName)

        if fm.fileExists(atPath: helper.path) {
            let installed = try Data(contentsOf: helper)
            if !Self.isWrapper(installed) {
                // A fresh helper from Steam (first install or update) replaces the saved one.
                if fm.fileExists(atPath: real.path) { try fm.removeItem(at: real) }
                try fm.moveItem(at: helper, to: real)
            } else if try installed != Data(contentsOf: wrapper) {
                try fm.removeItem(at: helper)
            }
        }
        guard fm.fileExists(atPath: real.path) else { return false }
        if !fm.fileExists(atPath: helper.path) {
            try fm.copyItem(at: wrapper, to: helper)
        }
        return true
    }

    static func isWrapper(_ data: Data) -> Bool {
        data.count < 1_000_000 && data.range(of: Data(marker.utf8)) != nil
    }
}
