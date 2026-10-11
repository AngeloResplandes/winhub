import Foundation

/// Whether a bottle has Wine processes running. Each prefix has one
/// `wineserver`, which keeps a socket in `/tmp/.wine-<uid>/server-<dev>-<inode>/`
/// (device and inode of the prefix folder, in hex) while it is alive.
public enum WineServerStatus {
    public static func isRunning(prefix: URL) -> Bool {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: prefix.path),
              let device = (attributes[.systemNumber] as? NSNumber)?.uint64Value,
              let inode = (attributes[.systemFileNumber] as? NSNumber)?.uint64Value else { return false }
        return FileManager.default.fileExists(atPath: socketURL(device: device, inode: inode).path)
    }

    static func socketURL(device: UInt64, inode: UInt64, uid: uid_t = getuid()) -> URL {
        URL(fileURLWithPath: "/tmp/.wine-\(uid)/server-\(String(device, radix: 16))-\(String(inode, radix: 16))/socket")
    }
}
