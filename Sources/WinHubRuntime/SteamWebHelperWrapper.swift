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

    static let folder = "Program Files (x86)/Steam/bin/cef/cef.win64"
    static let helperName = "steamwebhelper.exe"
    static let realName = "steamwebhelper_real.exe"

    /// Text embedded in every build of the wrapper, so that an older one is never
    /// mistaken for Steam's helper (it would then start itself in a loop).
    public static let marker = "WINHUB-STEAMWEBHELPER-WRAPPER"

    /// Puts the wrapper in place, again after Steam updates its helper.
    /// Returns `false` when the wrapper is not in place afterwards (no Steam helper to wrap).
    ///
    /// `onlyIfNeverWrapped` is for checks while Steam runs: only a bottle without a saved
    /// helper (Steam just installed its client) is changed. Steam started without
    /// `-noverifyfiles` restores its helper and restarts, so wrapping it again then
    /// would make both undo each other in a loop; the next launch from WinHub fixes it.
    @discardableResult
    public func install(in bottle: Bottle, onlyIfNeverWrapped: Bool = false) throws -> Bool {
        let fm = FileManager.default
        let cef = bottle.driveC.appending(path: Self.folder, directoryHint: .isDirectory)
        let helper = cef.appending(path: Self.helperName)
        let real = cef.appending(path: Self.realName)

        if onlyIfNeverWrapped, fm.fileExists(atPath: real.path) {
            return try fm.fileExists(atPath: helper.path) && Self.isWrapper(Data(contentsOf: helper))
        }
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
