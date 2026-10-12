import Foundation

/// The bottle's own compatibility rules, read by engines that pick the Direct3D themselves
/// (`WINHUB_COMPAT_RULES`; format in winhub-engine's `docs/compatdb.md`). WinHub writes one rule per
/// program with its own Direct3D and keeps any other rule in the file as it is.
public enum CompatRules {
    public static func url(for bottle: Bottle) -> URL {
        bottle.folder.appending(path: "compat-rules.json")
    }

    /// `desc` of the rules WinHub manages, followed by the program's Windows path.
    static let programPrefix = "winhub-program:"

    /// The Direct3D the bottle's rules give a program, if WinHub wrote one.
    public static func programBackend(_ program: String, in bottle: Bottle) -> GraphicsBackend? {
        let rule = rules(in: bottle).first { ($0["desc"] as? String) == programPrefix + program }
        let hacks = rule?["hacks"] as? [[String: Any]] ?? []
        return hacks.lazy.compactMap { ($0["backend"] as? String).flatMap(GraphicsBackend.init(rawValue:)) }.first
    }

    /// Gives a program its own Direct3D (`nil` or `.auto`: removes WinHub's rule for it). The rule is
    /// forced so it also wins over the bottle's choice.
    public static func setProgramBackend(_ backend: GraphicsBackend?, program: String, in bottle: Bottle) throws {
        var list = rules(in: bottle).filter { ($0["desc"] as? String) != programPrefix + program }
        if let backend, backend != .auto {
            list.append([
                "desc": programPrefix + program,
                "match": ["type": "path_suffix", "suffix": program],
                "hacks": [["type": "graphics_backend", "backend": backend.rawValue, "force": true]],
            ])
        }
        let data = try JSONSerialization.data(withJSONObject: ["version": 1, "rules": list],
                                              options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        try data.write(to: url(for: bottle), options: .atomic)
    }

    private static func rules(in bottle: Bottle) -> [[String: Any]] {
        guard let data = try? Data(contentsOf: url(for: bottle)),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [] }
        return root["rules"] as? [[String: Any]] ?? []
    }
}

/// Apple's D3DMetal (Game Porting Toolkit). WinHub never ships it: it is used only when the user has
/// the toolkit's `redist/lib` folder (with `wine/` and `external/`) in `defaultLocation` or in a folder
/// chosen in the settings (`location`).
public enum D3DMetal {
    public static var defaultLocation: URL {
        URL.applicationSupportDirectory.appending(path: "WinHub/D3DMetal", directoryHint: .isDirectory)
    }

    static let locationKey = "D3DMetalLocation"

    /// The folder chosen in the settings, or `defaultLocation`.
    public static var location: URL {
        get {
            UserDefaults.standard.string(forKey: locationKey).map { URL(fileURLWithPath: $0, isDirectory: true) }
                ?? defaultLocation
        }
        set {
            if newValue.standardizedFileURL == defaultLocation.standardizedFileURL {
                UserDefaults.standard.removeObject(forKey: locationKey)
            } else {
                UserDefaults.standard.set(newValue.path, forKey: locationKey)
            }
        }
    }

    /// The folder if it holds the D3DMetal DLLs and framework.
    public static func installed(at location: URL = location) -> URL? {
        let required = ["wine/x86_64-windows/d3d12.dll", "wine/x86_64-unix/d3d12.so", "external/D3DMetal.framework"]
        return required.allSatisfy { FileManager.default.fileExists(atPath: location.appending(path: $0).path) }
            ? location : nil
    }

    /// D3DMetal's folder inside a folder the user picked: the toolkit itself, its `redist` or its `redist/lib`.
    public static func resolve(_ picked: URL) -> URL? {
        ["", "lib", "redist/lib"].lazy
            .map { $0.isEmpty ? picked : picked.appending(path: $0, directoryHint: .isDirectory) }
            .compactMap { installed(at: $0) }
            .first
    }

    static func sharedLibrary(in location: URL) -> URL {
        location.appending(path: "external/libd3dshared.dylib")
    }
}
