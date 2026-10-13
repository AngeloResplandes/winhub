import Foundation

/// Ends a process that is not a child of WinHub (so it cannot be waited for): gives it `grace` to exit by
/// itself, then sends SIGTERM, then SIGKILL, waiting `grace` after each.
enum ProcessTerminator {
    /// Whether the process is gone.
    @discardableResult
    static func end(_ pid: pid_t, grace: Duration) async -> Bool {
        for signal in [0, SIGTERM, SIGKILL] {
            if signal != 0 { kill(pid, signal) }
            if await waitForExit(pid, timeout: grace) { return true }
        }
        return false
    }

    private static func waitForExit(_ pid: pid_t, timeout: Duration) async -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now + timeout
        while clock.now < deadline {
            if WineServerStatus.executablePath(pid: pid) == nil { return true }
            try? await Task.sleep(for: .milliseconds(50))
        }
        return WineServerStatus.executablePath(pid: pid) == nil
    }
}
