import Foundation
import Testing
@testable import WinHubRuntime

@Suite struct AppVersionTests {
    @Test func parsesAndCompares() throws {
        let version = try #require(AppVersion("v0.2.57"))
        #expect(version.components == [0, 2, 57])
        #expect(version.description == "0.2.57")
        #expect(AppVersion("0.2.10")! > AppVersion("0.2.9")!)
        #expect(AppVersion("0.2.1")! > AppVersion("0.1.0")!)
        #expect(AppVersion("0.2") == AppVersion("0.2.0"))
        #expect(AppVersion("1.0")! > AppVersion("0.99.99")!)
    }

    @Test func rejectsNonNumericVersions() {
        #expect(AppVersion("") == nil)
        #expect(AppVersion("0.2.beta") == nil)
        #expect(AppVersion("0..1") == nil)
    }
}

@Suite struct GitHubReleaseTests {
    static let json = """
    {
      "tag_name": "v0.2.3",
      "html_url": "https://github.com/AngeloResplandes/winhub/releases/tag/v0.2.3",
      "body": "notes",
      "assets": [
        {"name": "Other.zip", "size": 1, "digest": null,
         "browser_download_url": "https://example.invalid/Other.zip"},
        {"name": "WinHub.zip", "size": 1044161,
         "digest": "sha256:C1068011BAB30657BEDC920950A0E9D46DA3452AF6D37C60726E7ADE4DE30BD8",
         "browser_download_url": "https://example.invalid/WinHub.zip"}
      ]
    }
    """

    @Test func decodesTheAppAsset() throws {
        let release = try JSONDecoder().decode(GitHubRelease.self, from: Data(Self.json.utf8))
        #expect(release.version == AppVersion("0.2.3"))
        let asset = try #require(release.appAsset)
        #expect(asset.url.lastPathComponent == "WinHub.zip")
        #expect(asset.sha256 == "c1068011bab30657bedc920950a0e9d46da3452af6d37c60726e7ade4de30bd8")
    }

    @Test func ignoresAnAppWithoutDigest() throws {
        let json = Self.json.replacingOccurrences(of: "\"sha256:C10", with: "\"md5:C10")
        let release = try JSONDecoder().decode(GitHubRelease.self, from: Data(json.utf8))
        #expect(release.appAsset == nil)
    }
}

/// A minimal app bundle signed ad-hoc, zipped the way `package-app.sh` does it.
func makeFakeApp(in dir: URL, identifier: String = AppUpdater.bundleIdentifier, version: String) throws -> URL {
    let app = dir.appending(path: "WinHub.app", directoryHint: .isDirectory)
    let macOS = app.appending(path: "Contents/MacOS", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: macOS, withIntermediateDirectories: true)
    try FileManager.default.copyItem(at: URL(fileURLWithPath: "/usr/bin/true"), to: macOS.appending(path: "WinHub"))
    let info: [String: Any] = ["CFBundleIdentifier": identifier, "CFBundleExecutable": "WinHub",
                               "CFBundlePackageType": "APPL", "CFBundleShortVersionString": version]
    try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
        .write(to: app.appending(path: "Contents/Info.plist"))
    let sign = try ProcessRunner.run(URL(fileURLWithPath: "/usr/bin/codesign"), arguments: ["--force", "--sign", "-", app.path])
    #expect(sign.status == 0, "\(sign.output)")
    return app
}

@Suite struct AppUpdaterTests {
    @Test func extractsAndValidatesAStagedApp() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let source = try makeFakeApp(in: dir.appending(path: "build"), version: "0.2.3")
        let zip = dir.appending(path: "download/WinHub.zip")
        try FileManager.default.createDirectory(at: zip.deletingLastPathComponent(), withIntermediateDirectories: true)
        let ditto = try ProcessRunner.run(URL(fileURLWithPath: "/usr/bin/ditto"),
                                          arguments: ["-c", "-k", "--keepParent", source.path, zip.path])
        #expect(ditto.status == 0)

        let staged = dir.appending(path: "download/Staged.app")
        try AppUpdater.extractApp(from: zip, to: staged)
        try AppUpdater.validate(staged, version: AppVersion("0.2.3")!, current: nil)
        #expect(throws: AppUpdateError.self) {
            try AppUpdater.validate(staged, version: AppVersion("0.2.4")!, current: nil)
        }
    }

    @Test func rejectsAnotherApp() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let app = try makeFakeApp(in: dir, identifier: "com.example.other", version: "0.2.3")
        #expect(throws: AppUpdateError.invalidApp("identificador diferente")) {
            try AppUpdater.validate(app, version: AppVersion("0.2.3")!, current: nil)
        }
    }

    @Test func rejectsATamperedApp() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let app = try makeFakeApp(in: dir, version: "0.2.3")
        try Data("changed".utf8).write(to: app.appending(path: "Contents/MacOS/WinHub"))
        #expect(throws: AppUpdateError.invalidApp("assinatura inválida")) {
            try AppUpdater.validate(app, version: AppVersion("0.2.3")!, current: nil)
        }
    }

    @Test func installScriptQuotesPathsAndIsValidShell() throws {
        let current = URL(fileURLWithPath: "/Applications/Win Hub's.app")
        let staged = URL(fileURLWithPath: "/tmp/x/WinHub.app")
        let script = AppUpdater.installScript(current: current, staged: staged, pid: 123)
        #expect(script.contains("kill -0 123"))
        #expect(script.contains("'/Applications/Win Hub'\\''s.app.old'"))
        #expect(script.hasSuffix("open '/Applications/Win Hub'\\''s.app'"))
        let check = try ProcessRunner.run(URL(fileURLWithPath: "/bin/sh"), arguments: ["-n", "-c", script])
        #expect(check.status == 0, "\(check.output)")
    }

    @Test func onlyReplacesRealBundles() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        #expect(AppUpdater.canReplace(dir.appending(path: "WinHub.app")))
        #expect(!AppUpdater.canReplace(dir.appending(path: "WinHub")))
        #expect(!AppUpdater.canReplace(URL(fileURLWithPath: "/private/var/folders/x/AppTranslocation/ABC/d/WinHub.app")))
    }
}

@Suite struct RemoteDataSyncTests {
    @Test func savesValidFilesAndKeepsThePreviousCopyOtherwise() async throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let remote = dir.appending(path: "remote", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: remote, withIntermediateDirectories: true)
        let sync = RemoteDataSync(baseURL: remote, directory: dir.appending(path: "local", directoryHint: .isDirectory))
        let files = [
            RemoteDataSync.File(name: "list.json") { _ = try JSONDecoder().decode([Int].self, from: $0) },
            RemoteDataSync.File(name: "missing.json") { _ in },
        ]

        try Data("[1, 2]".utf8).write(to: remote.appending(path: "list.json"))
        #expect(await sync.sync(files) == ["list.json"])
        #expect(await sync.sync(files).isEmpty)

        try Data("{broken".utf8).write(to: remote.appending(path: "list.json"))
        #expect(await sync.sync(files).isEmpty)
        #expect(try String(contentsOf: sync.localURL(for: "list.json"), encoding: .utf8) == "[1, 2]")
        #expect(!FileManager.default.fileExists(atPath: sync.localURL(for: "missing.json").path))
    }

    @Test func pointsAtTheRepositoryResources() {
        #expect(RemoteDataSync.baseURL(repository: "owner/repo").appending(path: "catalog.json").absoluteString
                == "https://raw.githubusercontent.com/owner/repo/main/Sources/WinHub/Resources/catalog.json")
    }
}

@Suite struct InstalledRuntimesTests {
    @Test func findsRuntimesNoLongerInTheManifest() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let (archive, manifest) = try makeFakeRuntimeArchive(in: dir)
        let manager = RuntimeManager(root: dir.appending(path: "runtimes"))
        #expect(manager.installedRuntimes().isEmpty)
        _ = try manager.installArchive(at: archive, manifest: manifest)
        #expect(manager.installedRuntimes().map(\.manifest) == [manifest])
    }
}
