import Foundation
import Testing
@testable import WinHubRuntime

/// Little-endian byte writer for the synthetic files below.
private struct Bytes {
    var data = Data()
    mutating func u8(_ v: UInt8) { data.append(v) }
    mutating func u16(_ v: UInt16) { data.append(contentsOf: [UInt8(v & 0xFF), UInt8(v >> 8)]) }
    mutating func u32(_ v: UInt32) { for i in 0..<4 { data.append(UInt8((v >> (8 * UInt32(i))) & 0xFF)) } }
    mutating func raw(_ bytes: [UInt8]) { data.append(contentsOf: bytes) }
    mutating func zeros(_ count: Int) { data.append(Data(count: count)) }
    mutating func pad(to size: Int) { if data.count < size { zeros(size - data.count) } }
}

/// One image of an icon group: its GRPICONDIRENTRY fields and pixel data.
struct FakeIconImage {
    var width: UInt8
    var bytes: [UInt8]
}

/// A 64-bit PE with one `.rsrc` section holding RT_ICON images (ids 1…n) and one RT_GROUP_ICON (id 1).
func makeFakePEWithIcons(_ images: [FakeIconImage]) -> Data {
    let rva: UInt32 = 0x1000, rawOffset = 0x200

    // Resource tree: root (types) -> per type, one name -> per name, one language -> data entry.
    var group = Bytes()
    group.u16(0); group.u16(1); group.u16(UInt16(images.count))
    for (i, image) in images.enumerated() {
        group.u8(image.width); group.u8(image.width); group.u8(0); group.u8(0)
        group.u16(1); group.u16(32); group.u32(UInt32(image.bytes.count)); group.u16(UInt16(i + 1))
    }
    let iconCount = images.count
    // Layout (offsets from the section start).
    let root = 0
    let iconTypeDir = 16 + 2 * 8
    let groupTypeDir = iconTypeDir + 16 + iconCount * 8
    let iconLangDirs = groupTypeDir + 16 + 8
    let groupLangDir = iconLangDirs + iconCount * (16 + 8)
    let iconEntries = groupLangDir + 16 + 8
    let groupEntry = iconEntries + iconCount * 16
    var dataOffset = groupEntry + 16
    var imageOffsets: [Int] = []
    for image in images { imageOffsets.append(dataOffset); dataOffset += image.bytes.count }
    let groupOffset = dataOffset
    let sectionSize = groupOffset + group.data.count

    var rsrc = Bytes()
    func directory(ids: [(UInt32, Int, Bool)]) {
        rsrc.zeros(12); rsrc.u16(0); rsrc.u16(UInt16(ids.count))
        for (id, offset, isDirectory) in ids { rsrc.u32(id); rsrc.u32(UInt32(offset) | (isDirectory ? 0x8000_0000 : 0)) }
    }
    _ = root
    directory(ids: [(3, iconTypeDir, true), (14, groupTypeDir, true)])
    directory(ids: (0..<iconCount).map { (UInt32($0 + 1), iconLangDirs + $0 * 24, true) })
    directory(ids: [(1, groupLangDir, true)])
    for i in 0..<iconCount { directory(ids: [(0x409, iconEntries + i * 16, false)]) }
    directory(ids: [(0x409, groupEntry, false)])
    for (i, image) in images.enumerated() {
        rsrc.u32(rva + UInt32(imageOffsets[i])); rsrc.u32(UInt32(image.bytes.count)); rsrc.u32(0); rsrc.u32(0)
    }
    rsrc.u32(rva + UInt32(groupOffset)); rsrc.u32(UInt32(group.data.count)); rsrc.u32(0); rsrc.u32(0)
    for image in images { rsrc.raw(image.bytes) }
    rsrc.data.append(group.data)
    precondition(rsrc.data.count == sectionSize)

    var pe = Bytes()
    pe.raw([0x4D, 0x5A]); pe.pad(to: 0x3C); pe.u32(0x40)
    pe.raw([0x50, 0x45, 0, 0])
    pe.u16(0x8664); pe.u16(1); pe.u32(0); pe.u32(0); pe.u32(0); pe.u16(0xF0); pe.u16(0x22)
    let optional = pe.data.count
    pe.u16(0x20B)
    pe.pad(to: optional + 112 + 2 * 8)             // data directories start at +112 (PE32+); resources are #2
    pe.u32(rva); pe.u32(UInt32(sectionSize))
    pe.pad(to: optional + 0xF0)
    pe.raw(Array(".rsrc".utf8)); pe.zeros(3)
    pe.u32(UInt32(sectionSize)); pe.u32(rva); pe.u32(UInt32(sectionSize)); pe.u32(UInt32(rawOffset))
    pe.zeros(16)
    pe.pad(to: rawOffset)
    pe.data.append(rsrc.data)
    return pe.data
}

/// A Unicode `.lnk` with a LinkInfo local base path and, optionally, an icon location.
func makeFakeShortcut(target: String, icon: String? = nil, iconIndex: Int32 = 0) -> Data {
    var lnk = Bytes()
    lnk.u32(0x4C)
    lnk.raw([0x01, 0x14, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0xC0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x46])
    lnk.u32(0x02 | 0x80 | (icon == nil ? 0 : 0x40))   // HasLinkInfo, IsUnicode, HasIconLocation
    lnk.zeros(4 + 24 + 4)                              // attributes, times, file size
    lnk.u32(UInt32(bitPattern: iconIndex))
    lnk.u32(1); lnk.u16(0); lnk.zeros(2 + 8)
    precondition(lnk.data.count == 0x4C)

    let volume: [UInt8] = [0x11, 0, 0, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0x10, 0, 0, 0, 0]
    let base = Array(target.utf8) + [0]
    let headerSize = 0x1C
    let size = headerSize + volume.count + base.count + 1
    lnk.u32(UInt32(size)); lnk.u32(UInt32(headerSize)); lnk.u32(1)
    lnk.u32(UInt32(headerSize)); lnk.u32(UInt32(headerSize + volume.count)); lnk.u32(0)
    lnk.u32(UInt32(headerSize + volume.count + base.count))
    lnk.raw(volume); lnk.raw(base); lnk.u8(0)

    if let icon {
        let units = Array(icon.utf16)
        lnk.u16(UInt16(units.count))
        for unit in units { lnk.u16(unit) }
    }
    lnk.u32(0)                                         // terminal extra data block
    return lnk.data
}

@Suite struct PEIconTests {
    let small = FakeIconImage(width: 16, bytes: Array(repeating: 0xAB, count: 40))
    let large = FakeIconImage(width: 32, bytes: Array(repeating: 0xCD, count: 72))

    @Test func buildsAnICOFileFromTheIconGroup() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let exe = dir.appending(path: "game.exe")
        try makeFakePEWithIcons([small, large]).write(to: exe)

        let ico = try #require(PEIcon.icoData(from: exe))
        var expected = Bytes()
        expected.u16(0); expected.u16(1); expected.u16(2)
        expected.u8(16); expected.u8(16); expected.u8(0); expected.u8(0); expected.u16(1); expected.u16(32)
        expected.u32(40); expected.u32(6 + 2 * 16)
        expected.u8(32); expected.u8(32); expected.u8(0); expected.u8(0); expected.u16(1); expected.u16(32)
        expected.u32(72); expected.u32(6 + 2 * 16 + 40)
        expected.raw(small.bytes); expected.raw(large.bytes)
        #expect(ico == expected.data)
    }

    @Test func returnsNilWithoutIcons() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let plain = dir.appending(path: "plain.exe")
        try makeFakePEWithIcons([]).write(to: plain)
        #expect(PEIcon.icoData(from: plain) == nil)

        let truncated = dir.appending(path: "truncated.exe")
        try makeFakePEWithIcons([small]).prefix(0x220).write(to: truncated)
        #expect(PEIcon.icoData(from: truncated) == nil)

        let text = dir.appending(path: "text.exe")
        try Data("not a program".utf8).write(to: text)
        #expect(PEIcon.icoData(from: text) == nil)
        #expect(PEIcon.icoData(from: dir.appending(path: "missing.exe")) == nil)
    }
}

@Suite struct ShellLinkTests {
    @Test func readsTargetAndIconLocation() throws {
        let link = try #require(ShellLink(data: makeFakeShortcut(target: #"C:\Games\Game\game.exe"#,
                                                                 icon: #"C:\Games\Game\game.ico"#, iconIndex: 2)))
        #expect(link.targetPath == #"C:\Games\Game\game.exe"#)
        #expect(link.iconLocation == #"C:\Games\Game\game.ico"#)
        #expect(link.iconIndex == 2)

        let plain = try #require(ShellLink(data: makeFakeShortcut(target: #"C:\App\app.exe"#)))
        #expect(plain.targetPath == #"C:\App\app.exe"#)
        #expect(plain.iconLocation == nil)
    }

    @Test func rejectsOtherFiles() {
        #expect(ShellLink(data: Data("hello".utf8)) == nil)
        #expect(ShellLink(data: makeFakeShortcut(target: #"C:\x.exe"#).prefix(0x50)) == nil)
    }
}

@Suite struct ProgramIconTests {
    func bottle(in dir: URL) -> Bottle {
        var bottle = Bottle(name: "B", runtimeID: "w")
        bottle.folder = dir
        return bottle
    }

    @Test func findsTheIconThroughTheShortcut() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let bottle = bottle(in: dir)
        let game = bottle.driveC.appending(path: "Games/Game")
        let menu = bottle.driveC.appending(path: "ProgramData/Microsoft/Windows/Start Menu/Programs")
        try FileManager.default.createDirectory(at: game, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: menu, withIntermediateDirectories: true)
        let pe = makeFakePEWithIcons([FakeIconImage(width: 16, bytes: [1, 2, 3])])
        try pe.write(to: game.appending(path: "game.exe"))

        let shortcut = menu.appending(path: "Game.lnk")
        try makeFakeShortcut(target: #"C:\Games\Game\game.exe"#).write(to: shortcut)
        let program = InstalledProgram(name: "Game", shortcut: shortcut)
        #expect(ProgramIcon.icoData(for: program, in: bottle) == PEIcon.icoData(from: game.appending(path: "game.exe")))

        // An icon location that is an .ico file is used as it is.
        try Data([0, 0, 1, 0, 9]).write(to: game.appending(path: "game.ico"))
        try makeFakeShortcut(target: #"C:\Games\Game\game.exe"#, icon: #"C:\Games\Game\game.ico"#).write(to: shortcut)
        #expect(ProgramIcon.icoData(for: program, in: bottle) == Data([0, 0, 1, 0, 9]))

        // A target outside the bottle or missing gives no icon.
        try makeFakeShortcut(target: #"D:\x.exe"#).write(to: shortcut)
        #expect(ProgramIcon.icoData(for: program, in: bottle) == nil)
    }
}
