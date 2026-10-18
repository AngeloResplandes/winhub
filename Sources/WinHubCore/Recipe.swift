import Foundation

/// How to install and open a catalog title. Recipes only describe steps that
/// were tested by hand and only point to official download URLs.
public struct Recipe: Codable, Sendable, Hashable {
    public struct Installer: Codable, Sendable, Hashable {
        public enum Kind: String, Codable, Sendable, Hashable {
            case exe, msi, zip
        }

        /// Official download URL of the installer.
        public var url: URL
        /// Optional SHA-256. Leave it out when the vendor updates the file in
        /// place (e.g. Steam's bootstrapper); HTTPS from the vendor is then trusted.
        public var sha256: String?
        /// Arguments for an unattended install, e.g. `["/S"]`.
        public var arguments: [String]
        /// Explicit installer kind. When omitted, `resolvedKind` uses the URL's extension.
        public var kind: Kind?
        /// Folder under the bottle's `drive_c` for a zip payload, e.g. `Program Files\App`.
        public var extractTo: String?

        public init(url: URL, sha256: String? = nil, arguments: [String] = [], kind: Kind? = nil,
                    extractTo: String? = nil) {
            self.url = url
            self.sha256 = sha256
            self.arguments = arguments
            self.kind = kind
            self.extractTo = extractTo
        }

        enum CodingKeys: String, CodingKey { case url, sha256, arguments, kind, extractTo }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            url = try c.decode(URL.self, forKey: .url)
            sha256 = try c.decodeIfPresent(String.self, forKey: .sha256)
            arguments = try c.decodeIfPresent([String].self, forKey: .arguments) ?? []
            kind = try c.decodeIfPresent(Kind.self, forKey: .kind)
            extractTo = try c.decodeIfPresent(String.self, forKey: .extractTo)
        }

        /// File name used for the downloaded installer.
        public var fileName: String {
            let name = url.lastPathComponent
            return name.isEmpty ? "setup.exe" : name
        }

        /// `kind` if the JSON set it, otherwise inferred from the URL (`.msi`, `.zip`, else `.exe`).
        public var resolvedKind: Kind {
            if let kind { return kind }
            switch url.pathExtension.lowercased() {
            case "msi": return .msi
            case "zip": return .zip
            default: return .exe
            }
        }
    }

    public struct Launch: Codable, Sendable, Hashable {
        /// Optional label for the Open menu when a recipe has several programs.
        public var name: String?
        /// Windows path of the program, e.g. `C:\Program Files (x86)\Steam\steam.exe`.
        public var windowsPath: String
        public var arguments: [String]

        public init(windowsPath: String, arguments: [String] = [], name: String? = nil) {
            self.name = name
            self.windowsPath = windowsPath
            self.arguments = arguments
        }

        enum CodingKeys: String, CodingKey { case name, windowsPath, arguments }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            name = try c.decodeIfPresent(String.self, forKey: .name)
            windowsPath = try c.decode(String.self, forKey: .windowsPath)
            arguments = try c.decodeIfPresent([String].self, forKey: .arguments) ?? []
        }

        /// Menu label: `name`, or the `.exe` file name.
        public var title: String {
            if let name, !name.isEmpty { return name }
            return windowsPath.split(whereSeparator: { $0 == "\\" || $0 == "/" }).last.map(String.init) ?? windowsPath
        }
    }

    public enum Step: Codable, Sendable, Hashable {
        case run(windowsPath: String, arguments: [String])
        case registry(key: String, value: String, data: String, type: String)
        case copy(from: String, to: String)

        enum CodingKeys: String, CodingKey {
            case kind, windowsPath, arguments, key, value, data, type, from, to
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            let kind = try c.decode(String.self, forKey: .kind)
            switch kind {
            case "run":
                self = .run(
                    windowsPath: try c.decode(String.self, forKey: .windowsPath),
                    arguments: try c.decodeIfPresent([String].self, forKey: .arguments) ?? []
                )
            case "registry":
                self = .registry(
                    key: try c.decode(String.self, forKey: .key),
                    value: try c.decode(String.self, forKey: .value),
                    data: try c.decode(String.self, forKey: .data),
                    type: try c.decodeIfPresent(String.self, forKey: .type) ?? "REG_SZ"
                )
            case "copy":
                self = .copy(
                    from: try c.decode(String.self, forKey: .from),
                    to: try c.decode(String.self, forKey: .to)
                )
            default:
                throw DecodingError.dataCorruptedError(
                    forKey: .kind, in: c, debugDescription: "Unknown recipe step kind “\(kind)”.")
            }
        }

        public func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .run(let windowsPath, let arguments):
                try c.encode("run", forKey: .kind)
                try c.encode(windowsPath, forKey: .windowsPath)
                try c.encode(arguments, forKey: .arguments)
            case .registry(let key, let value, let data, let type):
                try c.encode("registry", forKey: .kind)
                try c.encode(key, forKey: .key)
                try c.encode(value, forKey: .value)
                try c.encode(data, forKey: .data)
                try c.encode(type, forKey: .type)
            case .copy(let from, let to):
                try c.encode("copy", forKey: .kind)
                try c.encode(from, forKey: .from)
                try c.encode(to, forKey: .to)
            }
        }
    }

    public struct Settings: Codable, Sendable, Hashable {
        /// Raw `GraphicsBackend` value (`dxmt`, `dxvk`, `auto`…). Unknown values are ignored when applied.
        public var graphics: String?
        public var msync: Bool?
        public var environment: [String: String]?
        public var dllOverrides: [String: String]?

        public init(graphics: String? = nil, msync: Bool? = nil, environment: [String: String]? = nil,
                    dllOverrides: [String: String]? = nil) {
            self.graphics = graphics
            self.msync = msync
            self.environment = environment
            self.dllOverrides = dllOverrides
        }
    }

    public struct Rule: Codable, Sendable, Hashable {
        public struct Match: Codable, Sendable, Hashable {
            public var type: String
            public var suffix: String?
            /// compatdb `game_id` for `steam_game_id` matches.
            public var gameID: String?

            public init(type: String, suffix: String? = nil, gameID: String? = nil) {
                self.type = type
                self.suffix = suffix
                self.gameID = gameID
            }

            enum CodingKeys: String, CodingKey { case type, suffix, game_id }

            public init(from decoder: Decoder) throws {
                let c = try decoder.container(keyedBy: CodingKeys.self)
                type = try c.decode(String.self, forKey: .type)
                suffix = try c.decodeIfPresent(String.self, forKey: .suffix)
                gameID = try c.decodeIfPresent(String.self, forKey: .game_id)
            }

            public func encode(to encoder: Encoder) throws {
                var c = encoder.container(keyedBy: CodingKeys.self)
                try c.encode(type, forKey: .type)
                try c.encodeIfPresent(suffix, forKey: .suffix)
                try c.encodeIfPresent(gameID, forKey: .game_id)
            }
        }

        public struct Hack: Codable, Sendable, Hashable {
            public var type: String
            public var backend: String?
            public var force: Bool?
            public var name: String?
            public var value: String?

            public init(type: String, backend: String? = nil, force: Bool? = nil, name: String? = nil,
                        value: String? = nil) {
                self.type = type
                self.backend = backend
                self.force = force
                self.name = name
                self.value = value
            }
        }

        public var desc: String
        public var match: Match
        public var hacks: [Hack]

        public init(desc: String, match: Match, hacks: [Hack]) {
            self.desc = desc
            self.match = match
            self.hacks = hacks
        }
    }

    /// Name of the bottle the title goes into; reused if it already exists.
    public var bottleName: String
    /// Wine's Windows version code (`win10`, `win7`…).
    public var windowsVersion: String
    /// winetricks verbs installed before the installer runs, e.g. `["vcrun2022"]`.
    public var dependencies: [String]
    public var installer: Installer
    /// Primary program; always set after decoding (`launch` or the first of `launches`).
    public var launch: Launch
    /// Extra programs from JSON `launches`, not including `launch`.
    public var additionalLaunches: [Launch]
    public var steps: [Step]
    public var settings: Settings?
    public var rules: [Rule]
    public var minAppVersion: String?

    public var allLaunches: [Launch] { [launch] + additionalLaunches }

    public init(bottleName: String, windowsVersion: String = "win10", dependencies: [String] = [],
                installer: Installer, launch: Launch, additionalLaunches: [Launch] = [], steps: [Step] = [],
                settings: Settings? = nil, rules: [Rule] = [], minAppVersion: String? = nil) {
        self.bottleName = bottleName
        self.windowsVersion = windowsVersion
        self.dependencies = dependencies
        self.installer = installer
        self.launch = launch
        self.additionalLaunches = additionalLaunches
        self.steps = steps
        self.settings = settings
        self.rules = rules
        self.minAppVersion = minAppVersion
    }

    enum CodingKeys: String, CodingKey {
        case bottleName, windowsVersion, dependencies, installer, launch, launches, steps, settings, rules
        case minAppVersion
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        bottleName = try c.decode(String.self, forKey: .bottleName)
        windowsVersion = try c.decodeIfPresent(String.self, forKey: .windowsVersion) ?? "win10"
        dependencies = try c.decodeIfPresent([String].self, forKey: .dependencies) ?? []
        installer = try c.decode(Installer.self, forKey: .installer)
        if installer.resolvedKind == .zip, installer.extractTo?.isEmpty != false {
            throw DecodingError.dataCorruptedError(
                forKey: .installer, in: c, debugDescription: "Zip recipes need installer.extractTo.")
        }
        let decodedLaunch = try c.decodeIfPresent(Launch.self, forKey: .launch)
        let decodedLaunches = try c.decodeIfPresent([Launch].self, forKey: .launches) ?? []
        if let decodedLaunch {
            launch = decodedLaunch
            additionalLaunches = decodedLaunches.filter { $0 != decodedLaunch }
        } else if let first = decodedLaunches.first {
            launch = first
            additionalLaunches = Array(decodedLaunches.dropFirst())
        } else {
            throw DecodingError.keyNotFound(
                CodingKeys.launch,
                .init(codingPath: c.codingPath, debugDescription: "Recipe needs launch or launches."))
        }
        steps = try c.decodeIfPresent([Step].self, forKey: .steps) ?? []
        settings = try c.decodeIfPresent(Settings.self, forKey: .settings)
        rules = try c.decodeIfPresent([Rule].self, forKey: .rules) ?? []
        minAppVersion = try c.decodeIfPresent(String.self, forKey: .minAppVersion)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(bottleName, forKey: .bottleName)
        try c.encode(windowsVersion, forKey: .windowsVersion)
        try c.encode(dependencies, forKey: .dependencies)
        try c.encode(installer, forKey: .installer)
        try c.encode(launch, forKey: .launch)
        if !additionalLaunches.isEmpty { try c.encode(additionalLaunches, forKey: .launches) }
        if !steps.isEmpty { try c.encode(steps, forKey: .steps) }
        try c.encodeIfPresent(settings, forKey: .settings)
        if !rules.isEmpty { try c.encode(rules, forKey: .rules) }
        try c.encodeIfPresent(minAppVersion, forKey: .minAppVersion)
    }
}

/// The Steam client, used to open catalog titles that only have a `steamID`.
public enum SteamClient {
    public static let bottleName = "Steam"
    public static let windowsPath = #"C:\Program Files (x86)\Steam\steam.exe"#

    /// Whether an imported bottle that was WinHub's Steam bottle got another name (the catalog only uses "Steam").
    public static func isRenamedClientBottle(original: String, imported: String) -> Bool {
        original.caseInsensitiveCompare(bottleName) == .orderedSame && imported.caseInsensitiveCompare(original) != .orderedSame
    }

    /// Steam checks its files on start and would put back the original
    /// `steamwebhelper.exe` over WinHub's wrapper. Only used while the wrapper is
    /// installed: on the first start the check is what downloads Steam's client.
    public static func launchArguments(wrapperInstalled: Bool) -> [String] {
        wrapperInstalled ? ["-noverifyfiles"] : []
    }

    /// `steam://run/<id>` installs the game first if needed, then starts it.
    public static func runArguments(appID: Int, wrapperInstalled: Bool) -> [String] {
        launchArguments(wrapperInstalled: wrapperInstalled) + ["steam://run/\(appID)"]
    }

    /// Arguments for opening `windowsPath`; the Steam client gets `launchArguments` first.
    public static func arguments(forOpening windowsPath: String, _ arguments: [String] = [],
                                 wrapperInstalled: Bool) -> [String] {
        let normalize = { (path: String) in path.replacingOccurrences(of: "/", with: "\\").lowercased() }
        guard normalize(windowsPath) == normalize(Self.windowsPath) else { return arguments }
        let extra = launchArguments(wrapperInstalled: wrapperInstalled)
        return extra + arguments.filter { !extra.contains($0) }
    }

    /// The Start Menu shortcut that Steam's installer creates is named "Steam".
    public static func isClientShortcut(named name: String) -> Bool {
        name.caseInsensitiveCompare("Steam") == .orderedSame
    }
}
