import Foundation

/// Whether a bottle has Wine processes running. Each prefix has one
/// `wineserver`, which keeps a `lock` and a `socket` in `/tmp/.wine-<uid>/server-<dev>-<inode>/`
/// (device and inode of the prefix folder, in hex) and holds the lock while it is alive.
public enum WineServerStatus {
    public static func isRunning(prefix: URL) -> Bool {
        guard let directory = serverDirectory(prefix: prefix) else { return false }
        return isRunning(serverDirectory: directory)
    }

    /// The socket is not enough: it stays behind when the wineserver is killed.
    static func isRunning(serverDirectory: URL) -> Bool {
        lockOwner(serverDirectory: serverDirectory) != nil
    }

    /// The prefix's server folder, or `nil` if the prefix does not exist.
    public static func serverDirectory(prefix: URL) -> URL? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: prefix.path),
              let device = (attributes[.systemNumber] as? NSNumber)?.uint64Value,
              let inode = (attributes[.systemFileNumber] as? NSNumber)?.uint64Value else { return nil }
        return serverDirectory(device: device, inode: inode)
    }

    static func serverDirectory(device: UInt64, inode: UInt64, uid: uid_t = getuid()) -> URL {
        URL(fileURLWithPath: "/tmp/.wine-\(uid)/server-\(String(device, radix: 16))-\(String(inode, radix: 16))",
            isDirectory: true)
    }

    /// The process holding the write lock on `<serverDirectory>/lock`, i.e. the live
    /// wineserver (`wineserver -k` finds it the same way).
    static func lockOwner(serverDirectory: URL) -> pid_t? {
        let fd = open(serverDirectory.appending(path: "lock").path, O_RDWR)
        guard fd >= 0 else { return nil }
        defer { close(fd) }
        var lock = flock()
        lock.l_type = Int16(F_WRLCK)
        lock.l_whence = Int16(SEEK_SET)
        guard fcntl(fd, F_GETLK, &lock) == 0, lock.l_type != Int16(F_UNLCK) else { return nil }
        return lock.l_pid
    }
}
