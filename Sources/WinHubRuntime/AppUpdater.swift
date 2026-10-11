import Foundation

/// A dotted numeric version such as `0.2.57` (a leading `v` is ignored).
public struct AppVersion: Comparable, Hashable, Sendable, CustomStringConvertible {
    public let components: [Int]

    public init?(_ string: String) {
        var text = Substring(string.trimmingCharacters(in: .whitespaces))
        if text.first == "v" || text.first == "V" { text = text.dropFirst() }
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        let numbers = parts.compactMap { Int($0) }
        guard !parts.isEmpty, numbers.count == parts.count else { return nil }
        components = numbers
    }

    public var description: String { components.map(String.init).joined(separator: ".") }

    /// Missing components count as zero, so `0.2 == 0.2.0`.
    private func padded(to count: Int) -> [Int] {
        components + Array(repeating: 0, count: max(0, count - components.count))
    }

    public static func == (lhs: AppVersion, rhs: AppVersion) -> Bool {
        let count = max(lhs.components.count, rhs.components.count)
        return lhs.padded(to: count) == rhs.padded(to: count)
    }

    public func hash(into hasher: inout Hasher) {
        var trimmed = components
        while trimmed.last == 0 { trimmed.removeLast() }
        hasher.combine(trimmed)
    }

    public static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        let count = max(lhs.components.count, rhs.components.count)
        return lhs.padded(to: count).lexicographicallyPrecedes(rhs.padded(to: count))
    }
}

/// The parts of a GitHub release (REST API) the updater needs.
public struct GitHubRelease: Decodable, Sendable, Equatable {
    public struct Asset: Decodable, Sendable, Equatable {
        public var name: String
        public var url: URL
        public var size: Int64
        /// `sha256:<hex>`, computed by GitHub for every uploaded asset.
        public var digest: String?

        public var sha256: String? {
            guard let digest, digest.hasPrefix("sha256:") else { return nil }
            let hex = digest.dropFirst("sha256:".count).lowercased()
            return hex.count == 64 ? hex : nil
        }

        enum CodingKeys: String, CodingKey {
            case name, size, digest
            case url = "browser_download_url"
        }
    }

    public var tagName: String
    public var pageURL: URL
    public var assets: [Asset]

    enum CodingKeys: String, CodingKey {
        case assets
        case tagName = "tag_name"
        case pageURL = "html_url"
    }

    public static let appAssetName = "WinHub.zip"

    public var version: AppVersion? { AppVersion(tagName) }

    /// The packaged app; without a digest it cannot be verified, so it is ignored.
    public var appAsset: Asset? {
        assets.first { $0.name == Self.appAssetName && $0.sha256 != nil }
    }
}

public enum AppUpdateError: Error, LocalizedError, Equatable {
    case badResponse(Int)
    case missingAsset
    case extractionFailed(String)
    case invalidApp(String)

    public var errorDescription: String? {
        switch self {
        case .badResponse(let status): "O GitHub respondeu com o código \(status)."
        case .missingAsset: "A versão nova não tem um WinHub.zip com SHA-256 conferível."
        case .extractionFailed(let output): "Não foi possível abrir o WinHub.zip baixado. \(output)"
        case .invalidApp(let reason): "O app baixado foi recusado: \(reason)."
        }
    }
}

/// Finds, downloads and installs new WinHub releases published on GitHub.
public struct AppUpdater: Sendable {
    public static let bundleIdentifier = "io.github.winhub"
    public static let defaultRepository = "AngeloResplandes/winhub"

    public enum Check: Sendable, Equatable {
        case notModified
        case release(GitHubRelease, etag: String?)
    }

    /// `owner/name` on GitHub.
    public let repository: String
    public let cacheDirectory: URL

    public init(repository: String, cacheDirectory: URL = AppUpdater.defaultCacheDirectory) {
        self.repository = repository
        self.cacheDirectory = cacheDirectory
    }

    public static var defaultCacheDirectory: URL {
        URL.cachesDirectory.appending(path: "WinHub/Updates", directoryHint: .isDirectory)
    }

    /// The latest published release. Passing the previous `etag` makes an unchanged answer
    /// cheap (304 does not count against GitHub's limit for anonymous requests).
    public func latestRelease(etag: String?) async throws -> Check {
        var request = URLRequest(url: URL(string: "https://api.github.com/repos/\(repository)/releases/latest")!)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        if let etag { request.setValue(etag, forHTTPHeaderField: "If-None-Match") }
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 304 { return .notModified }
        guard (200..<300).contains(status) else { throw AppUpdateError.badResponse(status) }
        let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
        return .release(release, etag: (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "ETag"))
    }

    /// Downloads and checks the release's app. Returns the `.app` ready to replace `current`.
    public func stage(_ release: GitHubRelease, current: URL?) async throws -> URL {
        guard let version = release.version, let asset = release.appAsset else { throw AppUpdateError.missingAsset }
        let folder = cacheDirectory.appending(path: version.description, directoryHint: .isDirectory)
        let app = folder.appending(path: "WinHub.app", directoryHint: .isDirectory)
        if (try? Self.validate(app, version: version, current: current)) != nil { return app }

        // Older staged versions are no longer needed.
        try? FileManager.default.removeItem(at: cacheDirectory)
        let zip = try await Downloader(directory: folder).download(asset.url, fileName: asset.name, sha256: asset.sha256)
        try Self.extractApp(from: zip, to: app)
        try? FileManager.default.removeItem(at: zip)
        try Self.validate(app, version: version, current: current)
        return app
    }

    /// Unzips `zip` (made with `ditto -c -k --keepParent`) and moves its `.app` to `destination`.
    static func extractApp(from zip: URL, to destination: URL) throws {
        let extracted = zip.deletingLastPathComponent().appending(path: "extracted", directoryHint: .isDirectory)
        try? FileManager.default.removeItem(at: extracted)
        defer { try? FileManager.default.removeItem(at: extracted) }
        let result = try ProcessRunner.run(URL(fileURLWithPath: "/usr/bin/ditto"),
                                           arguments: ["-x", "-k", zip.path, extracted.path])
        guard result.status == 0 else { throw AppUpdateError.extractionFailed(result.output) }
        let items = try FileManager.default.contentsOfDirectory(at: extracted, includingPropertiesForKeys: nil)
        guard let app = items.first(where: { $0.pathExtension == "app" }) else {
            throw AppUpdateError.extractionFailed("Nenhum .app dentro do arquivo.")
        }
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: app, to: destination)
    }

    /// Rejects anything that is not a correctly signed WinHub of the expected version. When the
    /// running app is signed with a Developer ID, the new one must come from the same team.
    public static func validate(_ app: URL, version: AppVersion, current: URL?) throws {
        let plist = app.appending(path: "Contents/Info.plist")
        guard let data = try? Data(contentsOf: plist),
              let info = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            throw AppUpdateError.invalidApp("Info.plist ausente")
        }
        guard info["CFBundleIdentifier"] as? String == bundleIdentifier else {
            throw AppUpdateError.invalidApp("identificador diferente")
        }
        guard (info["CFBundleShortVersionString"] as? String).flatMap(AppVersion.init) == version else {
            throw AppUpdateError.invalidApp("versão diferente da anunciada")
        }
        let verify = try ProcessRunner.run(URL(fileURLWithPath: "/usr/bin/codesign"),
                                           arguments: ["--verify", "--deep", "--strict", app.path])
        guard verify.status == 0 else { throw AppUpdateError.invalidApp("assinatura inválida") }
        if let current, let team = teamIdentifier(of: current), teamIdentifier(of: app) != team {
            throw AppUpdateError.invalidApp("assinado por outro desenvolvedor")
        }
    }

    /// The signing team, or `nil` for ad-hoc signatures.
    static func teamIdentifier(of app: URL) -> String? {
        guard let result = try? ProcessRunner.run(URL(fileURLWithPath: "/usr/bin/codesign"),
                                                  arguments: ["-d", "--verbose=2", app.path]),
              result.status == 0 else { return nil }
        let line = result.output.split(separator: "\n").first { $0.hasPrefix("TeamIdentifier=") }
        guard let value = line?.dropFirst("TeamIdentifier=".count), value != "not set" else { return nil }
        return String(value)
    }

    /// Whether the running app can swap itself: a real bundle, not translocated by Gatekeeper,
    /// in a folder the user can write to.
    public static func canReplace(_ bundle: URL) -> Bool {
        bundle.pathExtension == "app"
            && !bundle.path.contains("/AppTranslocation/")
            && FileManager.default.isWritableFile(atPath: bundle.deletingLastPathComponent().path)
    }

    /// Shell script that waits for `pid` to quit, swaps `current` for `staged` (restoring the old
    /// app if the swap fails) and opens the result.
    public static func installScript(current: URL, staged: URL, pid: Int32) -> String {
        let old = quoted(current.path + ".old")
        let current = quoted(current.path)
        return """
        while kill -0 \(pid) 2>/dev/null; do sleep 0.2; done
        rm -rf \(old)
        if mv -f \(current) \(old); then
          if mv -f \(quoted(staged.path)) \(current); then rm -rf \(old); else mv -f \(old) \(current); fi
        fi
        open \(current)
        """
    }

    /// Starts the swap in a separate process; the caller must quit right after.
    public static func install(_ staged: URL, over current: URL, pid: Int32) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", installScript(current: current, staged: staged, pid: pid)]
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
    }

    static func quoted(_ text: String) -> String {
        "'" + text.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
