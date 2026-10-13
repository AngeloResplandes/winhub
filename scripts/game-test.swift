// Drives a Windows game in a WinHub bottle for compatibility tests (docs/compat/): starts it through the
// bottle's running Steam, picks its Direct3D, finds and captures its window, and sends keys and clicks the
// way a person would (macOS events, so the game gets them like real input). Build it once:
//
//   swiftc -O scripts/game-test.swift -o .build/game-test
//
// Needs Accessibility (keys, clicks) and Screen Recording (captures) for the app that runs it. While a
// test runs, the game takes the screen and keyboard: do not use the Mac. Test on a clone of a bottle,
// never with two Steam instances of the same bottle (AGENTS.md, "Testing games").
//
//   game-test launch <bottle folder> <steam app id>
//   game-test backend <bottle folder> <Windows path of the .exe> <auto|wined3d|dxmt|dxvk|d3dmetal>
//   game-test wait <window title part> [seconds]          prints: <window id> <pid> <width>x<height>
//   game-test shot <window id> <file.png> [max width]
//   game-test focus <window id>
//   game-test key <key>[+shift|+ctrl|+alt|+cmd] [hold seconds] [repeat]
//   game-test click <window id> <x 0…1> <y 0…1> [right]
//   game-test backend-of <pid>                             prints: d3dmetal, dxmt, dxvk or wined3d
//   game-test fps <pid> [seconds]                         average FPS from the Metal HUD log (needs
//                                                          MTL_HUD_ENABLED=1 and MTL_HUD_LOG_ENABLED=1 in the game)
//   game-test quit <pid>
import AppKit
import CoreGraphics
import Foundation

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

func run(_ path: String, _ arguments: [String], environment: [String: String]? = nil, wait: Bool = true) -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: path)
    process.arguments = arguments
    if let environment { process.environment = environment }
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = wait ? pipe : FileHandle.nullDevice
    if !wait { process.standardOutput = FileHandle.nullDevice }
    do { try process.run() } catch { fail("cannot run \(path): \(error)") }
    guard wait else { return "" }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    return String(decoding: data, as: UTF8.self)
}

// MARK: - Bottles and Steam

let home = FileManager.default.homeDirectoryForCurrentUser
let runtime = ProcessInfo.processInfo.environment["WINHUB_RUNTIME"]
    ?? home.appending(path: "Library/Application Support/WinHub/Runtimes/winhub-wine-11.0-r2/Wine Devel.app/Contents/Resources/wine").path

func bottleSettings(_ folder: String) -> [String: Any] {
    guard let data = FileManager.default.contents(atPath: folder + "/bottle.json"),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { fail("no bottle.json in \(folder)") }
    return json
}

/// Asks the bottle's running Steam to start the game. The bottle's msync setting must match the running wineserver.
func launch(bottle: String, appID: String) {
    let settings = bottleSettings(bottle)
    var env = ["HOME": home.path, "USER": NSUserName(), "WINEPREFIX": bottle + "/prefix", "WINEDEBUG": "-all",
               "ROSETTA_ADVERTISE_AVX": "1", "PATH": runtime + "/bin:/usr/bin:/bin"]
    if settings["msync"] as? Bool == true { env["WINEMSYNC"] = "1" }
    _ = run(runtime + "/bin/wine", [#"C:\Program Files (x86)\Steam\steam.exe"#, "-applaunch", appID],
            environment: env, wait: false)
}

/// The same rule WinHub writes for "Gráficos por programa" (CompatRules.setProgramBackend).
func setBackend(bottle: String, program: String, backend: String) {
    let url = URL(fileURLWithPath: bottle + "/compat-rules.json")
    let root = (try? JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]) ?? [:]
    let prefix = "winhub-program:"
    var rules = (root["rules"] as? [[String: Any]] ?? []).filter { ($0["desc"] as? String) != prefix + program }
    if backend != "auto" {
        rules.append(["desc": prefix + program, "match": ["type": "path_suffix", "suffix": program],
                      "hacks": [["type": "graphics_backend", "backend": backend, "force": true]]])
    }
    let data = try! JSONSerialization.data(withJSONObject: ["version": 1, "rules": rules],
                                           options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
    try! data.write(to: url, options: .atomic)
}

// MARK: - Windows

struct GameWindow { var id: Int; var pid: Int32; var frame: CGRect; var title: String }

func windows() -> [GameWindow] {
    let list = CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as? [[String: Any]] ?? []
    return list.compactMap { info in
        guard let id = info[kCGWindowNumber as String] as? Int, let pid = info[kCGWindowOwnerPID as String] as? Int32,
              let bounds = info[kCGWindowBounds as String] as? [String: Any],
              let frame = CGRect(dictionaryRepresentation: bounds as CFDictionary) else { return nil }
        return GameWindow(id: id, pid: pid, frame: frame, title: info[kCGWindowName as String] as? String ?? "")
    }
}

func window(_ id: Int) -> GameWindow {
    guard let found = windows().first(where: { $0.id == id }) else { fail("no window \(id)") }
    return found
}

// MARK: - Input

let keyCodes: [String: CGKeyCode] = [
    "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9, "b": 11, "q": 12, "w": 13,
    "e": 14, "r": 15, "y": 16, "t": 17, "1": 18, "2": 19, "3": 20, "4": 21, "6": 22, "5": 23, "9": 25, "7": 26,
    "8": 28, "0": 29, "o": 31, "u": 32, "i": 34, "p": 35, "l": 37, "j": 38, "k": 40, "n": 45, "m": 46,
    "return": 36, "enter": 36, "tab": 48, "space": 49, "backspace": 51, "esc": 53, "escape": 53,
    "left": 123, "right": 124, "down": 125, "up": 126, "pageup": 116, "pagedown": 121, "home": 115, "end": 119,
    "f1": 122, "f2": 120, "f3": 99, "f4": 118, "f5": 96, "f6": 97, "f7": 98, "f8": 100, "f9": 101, "f10": 109,
    "shift": 56, "ctrl": 59, "alt": 58, "cmd": 55,
]
let modifierFlags: [String: CGEventFlags] = ["shift": .maskShift, "ctrl": .maskControl, "alt": .maskAlternate, "cmd": .maskCommand]

func key(_ spec: String, hold: Double, times: Int) {
    let parts = spec.lowercased().split(separator: "+").map(String.init)
    guard let code = keyCodes[parts[0]] else { fail("unknown key \(parts[0])") }
    let flags = parts.dropFirst().reduce(CGEventFlags()) { $0.union(modifierFlags[$1] ?? []) }
    let source = CGEventSource(stateID: .hidSystemState)
    for _ in 0..<max(times, 1) {
        let down = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: true)!
        down.flags = flags
        down.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: max(hold, 0.05))
        let up = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: false)!
        up.flags = flags
        up.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: 0.15)
    }
}

func click(_ target: GameWindow, x: Double, y: Double, right: Bool) {
    let point = CGPoint(x: target.frame.minX + target.frame.width * x, y: target.frame.minY + target.frame.height * y)
    let source = CGEventSource(stateID: .hidSystemState)
    CGEvent(mouseEventSource: source, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left)?
        .post(tap: .cghidEventTap)
    Thread.sleep(forTimeInterval: 0.2)
    let (downType, upType, button): (CGEventType, CGEventType, CGMouseButton) =
        right ? (.rightMouseDown, .rightMouseUp, .right) : (.leftMouseDown, .leftMouseUp, .left)
    CGEvent(mouseEventSource: source, mouseType: downType, mouseCursorPosition: point, mouseButton: button)?.post(tap: .cghidEventTap)
    Thread.sleep(forTimeInterval: 0.08)
    CGEvent(mouseEventSource: source, mouseType: upType, mouseCursorPosition: point, mouseButton: button)?.post(tap: .cghidEventTap)
}

// MARK: - Commands

var args = Array(CommandLine.arguments.dropFirst())
guard let command = args.first else { fail("usage: see the top of scripts/game-test.swift") }
args.removeFirst()
func arg(_ i: Int) -> String {
    guard i < args.count else { fail("missing argument \(i + 1) for \(command)") }
    return args[i]
}

switch command {
case "launch":
    launch(bottle: arg(0), appID: arg(1))
case "backend":
    setBackend(bottle: arg(0), program: arg(1), backend: arg(2))
case "wait":
    let part = arg(0).lowercased()
    let deadline = Date().addingTimeInterval(Double(args.count > 1 ? arg(1) : "120") ?? 120)
    while Date() < deadline {
        if let found = windows().first(where: { $0.title.lowercased().contains(part) && $0.frame.width > 320 }) {
            print(found.id, found.pid, "\(Int(found.frame.width))x\(Int(found.frame.height))")
            exit(0)
        }
        Thread.sleep(forTimeInterval: 1)
    }
    fail("no window with “\(part)” in its title")
case "shot":
    let file = arg(1)
    _ = run("/usr/sbin/screencapture", ["-x", "-o", "-l\(arg(0))", file])
    if args.count > 2 { _ = run("/usr/bin/sips", ["-Z", arg(2), file, "--out", file]) }
    guard FileManager.default.fileExists(atPath: file) else { fail("capture failed") }
case "focus":
    let target = window(Int(arg(0))!)
    NSRunningApplication(processIdentifier: target.pid)?.activate()
    Thread.sleep(forTimeInterval: 0.8)
case "key":
    key(arg(0), hold: args.count > 1 ? Double(arg(1)) ?? 0 : 0, times: args.count > 2 ? Int(arg(2)) ?? 1 : 1)
case "click":
    click(window(Int(arg(0))!), x: Double(arg(1))!, y: Double(arg(2))!, right: args.count > 3 && arg(3) == "right")
case "backend-of":
    let files = run("/usr/sbin/lsof", ["-p", arg(0)]).lowercased()
    print(files.contains("d3dmetal.framework") ? "d3dmetal" : files.contains("/lib/dxmt/") || files.contains("winemetal.so") ? "dxmt"
          : files.contains("/lib/dxvk/") ? "dxvk" : "wined3d")
case "fps":
    // "metal-HUD: <frame>,<Metal MB>,<app MB>…" about once a second; the frame time itself is redacted.
    let seconds = args.count > 1 ? arg(1) : "10"
    let output = run("/usr/bin/log", ["show", "--last", "\(seconds)s", "--style", "compact", "--predicate",
                                      "processIdentifier == \(arg(0)) AND eventMessage BEGINSWITH \"metal-HUD:\" AND subsystem == \"com.apple.metal.hud\""])
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    let samples: [(Date, Int)] = output.split(separator: "\n").compactMap { line in
        guard let date = formatter.date(from: String(line.prefix(23))), let range = line.range(of: "metal-HUD: ") else { return nil }
        let frame = line[range.upperBound...].prefix { $0.isNumber }
        return Int(frame).map { (date, $0) }
    }
    guard let first = samples.first, let last = samples.last, last.0 > first.0 else { fail("no Metal HUD samples") }
    print(String(format: "%.1f", Double(last.1 - first.1) / last.0.timeIntervalSince(first.0)))
case "quit":
    kill(pid_t(arg(0))!, SIGTERM)
default:
    fail("unknown command \(command)")
}
