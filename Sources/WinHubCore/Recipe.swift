import Foundation

/// How to install and open a catalog title. Recipes only describe steps that
/// were tested by hand and only point to official download URLs.
public struct Recipe: Codable, Sendable, Hashable {
    public struct Installer: Codable, Sendable, Hashable {
        /// Official download URL of the installer.
        public var url: URL
        /// Optional SHA-256. Leave it out when the vendor updates the file in
        /// place (e.g. Steam's bootstrapper); HTTPS from the vendor is then trusted.
        public var sha256: String?
        /// Arguments for an unattended install, e.g. `["/S"]`.
        public var arguments: [String]

        public init(url: URL, sha256: String? = nil, arguments: [String] = []) {
            self.url = url
            self.sha256 = sha256
            self.arguments = arguments
        }

        enum CodingKeys: String, CodingKey { case url, sha256, arguments }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            url = try c.decode(URL.self, forKey: .url)
            sha256 = try c.decodeIfPresent(String.self, forKey: .sha256)
            arguments = try c.decodeIfPresent([String].self, forKey: .arguments) ?? []
        }

        /// File name used for the downloaded installer.
        public var fileName: String {
            let name = url.lastPathComponent
            return name.isEmpty ? "setup.exe" : name
        }
    }

    public struct Launch: Codable, Sendable, Hashable {
        /// Windows path of the program, e.g. `C:\Program Files (x86)\Steam\steam.exe`.
        public var windowsPath: String
        public var arguments: [String]

        public init(windowsPath: String, arguments: [String] = []) {
            self.windowsPath = windowsPath
            self.arguments = arguments
        }

        enum CodingKeys: String, CodingKey { case windowsPath, arguments }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            windowsPath = try c.decode(String.self, forKey: .windowsPath)
            arguments = try c.decodeIfPresent([String].self, forKey: .arguments) ?? []
        }
    }

    /// Name of the bottle the title goes into; reused if it already exists.
    public var bottleName: String
    /// Wine's Windows version code (`win10`, `win7`…).
    public var windowsVersion: String
    /// winetricks verbs installed before the installer runs, e.g. `["vcrun2022"]`.
    public var dependencies: [String]
    public var installer: Installer
    public var launch: Launch

    public init(bottleName: String, windowsVersion: String = "win10", dependencies: [String] = [],
                installer: Installer, launch: Launch) {
        self.bottleName = bottleName
        self.windowsVersion = windowsVersion
        self.dependencies = dependencies
        self.installer = installer
        self.launch = launch
    }

    enum CodingKeys: String, CodingKey { case bottleName, windowsVersion, dependencies, installer, launch }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        bottleName = try c.decode(String.self, forKey: .bottleName)
        windowsVersion = try c.decodeIfPresent(String.self, forKey: .windowsVersion) ?? "win10"
        dependencies = try c.decodeIfPresent([String].self, forKey: .dependencies) ?? []
        installer = try c.decode(Installer.self, forKey: .installer)
        launch = try c.decode(Launch.self, forKey: .launch)
    }
}

/// The Steam client, used to open catalog titles that only have a `steamID`.
public enum SteamClient {
    public static let bottleName = "Steam"
    public static let windowsPath = #"C:\Program Files (x86)\Steam\steam.exe"#

    /// `steam://run/<id>` installs the game first if needed, then starts it.
    public static func runArguments(appID: Int) -> [String] {
        ["steam://run/\(appID)"]
    }
}
