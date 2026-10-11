import Foundation

/// Finds and ends Wine processes left behind by a wineserver that is gone.
///
/// If the wineserver dies without ending its clients (for example killed with
/// SIGKILL), most of them exit when their next server call fails. Processes
/// that never call the server keep running: on macOS the `winedevice.exe` that
/// hosts `winebus.sys` loops in the IOHID run loop, and Wine handles SIGTERM by
/// ending only the thread that receives it. A new wineserver for the same prefix
/// reuses the folder, so every crash adds one more orphan. Only SIGKILL ends them.
///
/// Every Wine client maps `tmpmap-*` files from the prefix's server folder, so a
/// process referencing that folder while no wineserver holds its lock is an orphan.
public enum WineOrphanReaper {
    /// Ends the orphans of `prefix` and returns their pids. Does nothing while a
    /// wineserver is alive for the prefix.
    @discardableResult
    public static func reap(prefix: URL) -> [pid_t] {
        guard let directory = WineServerStatus.serverDirectory(prefix: prefix) else { return [] }
        return reap(serverDirectory: directory)
    }

    static func reap(serverDirectory: URL) -> [pid_t] {
        guard FileManager.default.fileExists(atPath: serverDirectory.path),
              !WineServerStatus.isRunning(serverDirectory: serverDirectory) else { return [] }
        let orphans = find(serverDirectory: serverDirectory)
        // A wineserver may have started for the prefix while lsof ran; its clients look the same.
        guard !orphans.isEmpty, !WineServerStatus.isRunning(serverDirectory: serverDirectory) else { return [] }
        return orphans.filter { kill($0, SIGKILL) == 0 }
    }

    /// Processes of the current user with a file, mapping or working directory in `serverDirectory`.
    static func find(serverDirectory: URL) -> [pid_t] {
        // `lsof +D` skips memory-mapped files, so list everything of this user and filter.
        guard let result = try? ProcessRunner.run(URL(fileURLWithPath: "/usr/sbin/lsof"),
                                                  arguments: ["-nPw", "+c", "0", "-F", "pcn", "-u", String(getuid())]) else { return [] }
        return pids(in: result.output, referencing: serverDirectory, excluding: getpid())
    }

    /// Parses `lsof -F pcn` output: `p<pid>` starts a process, `c<command>` names it
    /// and each `n<path>` is one of its files. The wineserver itself is never returned.
    static func pids(in lsofOutput: String, referencing directory: URL, excluding ownPID: pid_t) -> [pid_t] {
        let path = directory.standardizedFileURL.path
        // lsof prints resolved paths, and /tmp is a link to /private/tmp.
        let roots = [path, "/private" + path].map { $0.hasSuffix("/") ? String($0.dropLast()) : $0 }
        func isInside(_ name: Substring) -> Bool {
            roots.contains { name == $0 || name.hasPrefix($0 + "/") }
        }

        var found: [pid_t] = []
        var pid: pid_t?
        var command = ""
        var matches = false
        func finish() {
            if let pid, matches, pid != ownPID, command != "wineserver" { found.append(pid) }
        }
        for line in lsofOutput.split(separator: "\n") {
            switch line.first {
            case "p":
                finish()
                pid = pid_t(line.dropFirst())
                command = ""
                matches = false
            case "c": command = String(line.dropFirst())
            case "n": if isInside(line.dropFirst()) { matches = true }
            default: break
            }
        }
        finish()
        return found
    }
}
