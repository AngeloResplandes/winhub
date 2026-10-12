import Foundation

/// The icon of an installed program, as an `.ico` file's contents.
public enum ProgramIcon {
    /// Follows the shortcut: its icon location first (an `.ico`, or an `.exe`/`.dll` with icons), then its target.
    public static func icoData(for program: InstalledProgram, in bottle: Bottle) -> Data? {
        guard let data = try? Data(contentsOf: program.shortcut), let link = ShellLink(data: data) else { return nil }
        if let location = link.iconLocation, let file = bottle.unixPath(forWindowsPath: location) {
            if file.pathExtension.lowercased() == "ico" {
                if let ico = try? Data(contentsOf: file) { return ico }
            } else if let ico = PEIcon.icoData(from: file, index: link.iconIndex) {
                return ico
            }
        }
        guard let target = link.targetPath, let file = bottle.unixPath(forWindowsPath: target) else { return nil }
        return PEIcon.icoData(from: file)
    }
}

/// Reads an icon group from a Windows executable's resources (RT_GROUP_ICON and its RT_ICON images) and
/// rebuilds the `.ico` file it came from, which AppKit can open.
public enum PEIcon {
    /// `index`: which icon group, as in a shortcut (0 = first; negative = resource id). An index past the
    /// last group gives the first one.
    public static func icoData(from file: URL, index: Int32 = 0) -> Data? {
        guard let data = try? Data(contentsOf: file, options: .alwaysMapped) else { return nil }
        return icoData(fromPE: data, index: index)
    }

    private struct Section { var address: UInt32, size: UInt32, rawOffset: UInt32 }
    private struct Entry { var id: UInt32, isNamed: Bool, offset: Int, isDirectory: Bool }

    static func icoData(fromPE data: Data, index: Int32) -> Data? {
        let r = ByteReader(data)
        guard r.u16(0) == 0x5A4D, let pe = r.u32(0x3C).map(Int.init), r.u32(pe) == 0x0000_4550,
              let sectionCount = r.u16(pe + 6), let optionalSize = r.u16(pe + 20), let magic = r.u16(pe + 24) else { return nil }
        let optional = pe + 24
        let directories: Int
        switch magic {
        case 0x20B: directories = optional + 112      // PE32+
        case 0x10B: directories = optional + 96       // PE32
        default: return nil
        }
        guard let resourceRVA = r.u32(directories + 2 * 8), resourceRVA != 0 else { return nil }

        var sections: [Section] = []
        let table = optional + Int(optionalSize)
        for i in 0..<Int(sectionCount) {
            let entry = table + i * 40
            guard let virtualSize = r.u32(entry + 8), let address = r.u32(entry + 12),
                  let rawSize = r.u32(entry + 16), let rawOffset = r.u32(entry + 20) else { return nil }
            sections.append(Section(address: address, size: max(virtualSize, rawSize), rawOffset: rawOffset))
        }
        func fileOffset(_ rva: UInt32) -> Int? {
            sections.first { rva >= $0.address && rva - $0.address < $0.size }
                .map { Int($0.rawOffset) + Int(rva - $0.address) }
        }
        guard let base = fileOffset(resourceRVA) else { return nil }

        func entries(_ directory: Int) -> [Entry]? {
            guard let named = r.u16(directory + 12), let ids = r.u16(directory + 14) else { return nil }
            return (0..<Int(named) + Int(ids)).compactMap { i in
                guard let name = r.u32(directory + 16 + i * 8), let target = r.u32(directory + 20 + i * 8) else { return nil }
                return Entry(id: name & 0x7FFF_FFFF, isNamed: name & 0x8000_0000 != 0,
                             offset: Int(target & 0x7FFF_FFFF), isDirectory: target & 0x8000_0000 != 0)
            }
        }
        // The data of an entry: down through the first child of each directory (the first language).
        func resource(_ entry: Entry) -> Data? {
            var current = entry
            for _ in 0..<3 where current.isDirectory {
                guard let first = entries(base + current.offset)?.first else { return nil }
                current = first
            }
            guard !current.isDirectory, let rva = r.u32(base + current.offset), let size = r.u32(base + current.offset + 4),
                  let offset = fileOffset(rva) else { return nil }
            return r.bytes(offset, count: Int(size))
        }

        guard let types = entries(base),
              let groupType = types.first(where: { !$0.isNamed && $0.id == 14 && $0.isDirectory }),
              let iconType = types.first(where: { !$0.isNamed && $0.id == 3 && $0.isDirectory }),
              let groups = entries(base + groupType.offset), !groups.isEmpty,
              let icons = entries(base + iconType.offset) else { return nil }
        let chosen = index < 0
            ? groups.first { !$0.isNamed && $0.id == UInt32(-Int64(index)) }
            : groups.indices.contains(Int(index)) ? groups[Int(index)] : groups.first
        guard let chosen, let group = resource(chosen), let count = ByteReader(group).u16(4) else { return nil }

        // GRPICONDIRENTRY (14 bytes) -> ICONDIRENTRY (16 bytes) pointing into the file.
        let g = ByteReader(group)
        var images: [(header: Data, image: Data)] = []
        for i in 0..<Int(count) {
            let entry = 6 + i * 14
            guard let header = g.bytes(entry, count: 12), let id = g.u16(entry + 12),
                  let icon = icons.first(where: { !$0.isNamed && $0.id == UInt32(id) }),
                  let image = resource(icon) else { continue }
            images.append((Data(header.prefix(8)), image))
        }
        guard !images.isEmpty else { return nil }

        var ico = Data([0, 0, 1, 0])
        ico.append(littleEndian: UInt16(images.count))
        var offset = 6 + images.count * 16
        for (header, image) in images {
            ico.append(header)
            ico.append(littleEndian: UInt32(image.count))
            ico.append(littleEndian: UInt32(offset))
            offset += image.count
        }
        for (_, image) in images { ico.append(image) }
        return ico
    }
}

extension Data {
    mutating func append<T: FixedWidthInteger>(littleEndian value: T) {
        Swift.withUnsafeBytes(of: value.littleEndian) { append(contentsOf: $0) }
    }
}
