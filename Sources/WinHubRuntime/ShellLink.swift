import Foundation

/// The parts of a Windows shortcut (`.lnk`, Microsoft's public MS-SHLLINK format) WinHub needs:
/// the program it opens and where its icon is.
public struct ShellLink: Sendable, Equatable {
    /// Windows path of the target, from the shortcut's LinkInfo (e.g. `C:\Games\Game\game.exe`).
    public var targetPath: String?
    /// Windows path of the file holding the icon, when the shortcut names one.
    public var iconLocation: String?
    /// Icon in that file: an index (0 = first) or, when negative, a resource id.
    public var iconIndex: Int32

    static let clsid: [UInt8] = [0x01, 0x14, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00,
                                 0xC0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x46]

    public init?(data: Data) {
        let r = ByteReader(data)
        guard r.u32(0) == 0x4C, r.bytes(4, count: 16).map(Array.init) == Self.clsid,
              let flags = r.u32(0x14), let index = r.u32(0x38) else { return nil }
        iconIndex = Int32(bitPattern: index)

        var offset = 0x4C
        if flags & 0x01 != 0 {                        // HasLinkTargetIDList
            guard let size = r.u16(offset) else { return nil }
            offset += 2 + Int(size)
        }
        if flags & 0x02 != 0 {                        // HasLinkInfo
            guard let size = r.u32(offset), let header = r.u32(offset + 4), let infoFlags = r.u32(offset + 8),
                  size >= header else { return nil }
            if infoFlags & 0x01 != 0 {                // VolumeIDAndLocalBasePath
                targetPath = Self.localPath(r, info: offset, unicode: header >= 0x24)
            }
            offset += Int(size)
        }

        // StringData, in order: name, relative path, working dir, arguments, icon location.
        let unicode = flags & 0x80 != 0
        var strings: [String?] = []
        for bit: UInt32 in [0x04, 0x08, 0x10, 0x20, 0x40] {
            guard flags & bit != 0 else { strings.append(nil); continue }
            guard let count = r.u16(offset) else { return nil }
            let length = Int(count) * (unicode ? 2 : 1)
            guard let text = r.string(offset + 2, length: length, unicode: unicode) else { return nil }
            strings.append(text.isEmpty ? nil : text)
            offset += 2 + length
        }
        iconLocation = strings[4]
    }

    /// LocalBasePath + CommonPathSuffix, preferring the Unicode copies.
    private static func localPath(_ r: ByteReader, info: Int, unicode: Bool) -> String? {
        if unicode, let base = r.u32(info + 0x1C), base != 0, let path = r.utf16z(info + Int(base)) {
            let suffix = r.u32(info + 0x20).flatMap { $0 == 0 ? nil : r.utf16z(info + Int($0)) } ?? ""
            return path + suffix
        }
        guard let base = r.u32(info + 0x10), base != 0, let path = r.cstring(info + Int(base)) else { return nil }
        let suffix = r.u32(info + 0x18).flatMap { $0 == 0 ? nil : r.cstring(info + Int($0)) } ?? ""
        return path.isEmpty ? nil : path + suffix
    }
}

/// Bounds-checked little-endian reads; every read past the end gives `nil`.
struct ByteReader {
    let data: Data

    init(_ data: Data) { self.data = data }

    func bytes(_ offset: Int, count: Int) -> Data? {
        guard offset >= 0, count >= 0, offset <= data.count - count else { return nil }
        let start = data.startIndex + offset
        return data[start..<start + count]
    }

    func u16(_ offset: Int) -> UInt16? {
        bytes(offset, count: 2).map { UInt16($0[$0.startIndex]) | UInt16($0[$0.startIndex + 1]) << 8 }
    }

    func u32(_ offset: Int) -> UInt32? {
        bytes(offset, count: 4).map { b in (0..<4).reduce(UInt32(0)) { $0 | UInt32(b[b.startIndex + $1]) << (8 * UInt32($1)) } }
    }

    func string(_ offset: Int, length: Int, unicode: Bool) -> String? {
        guard let raw = bytes(offset, count: length) else { return nil }
        return unicode ? String(data: raw, encoding: .utf16LittleEndian) : String(data: raw, encoding: .windowsCP1252)
    }

    /// Zero-terminated 8-bit string (Windows ANSI).
    func cstring(_ offset: Int) -> String? {
        guard offset >= 0, offset < data.count else { return nil }
        let start = data.startIndex + offset
        guard let end = data[start...].firstIndex(of: 0) else { return nil }
        return String(data: data[start..<end], encoding: .windowsCP1252)
    }

    /// Zero-terminated UTF-16LE string.
    func utf16z(_ offset: Int) -> String? {
        var end = offset
        while true {
            guard let unit = u16(end) else { return nil }
            if unit == 0 { break }
            end += 2
        }
        return string(offset, length: end - offset, unicode: true)
    }
}
