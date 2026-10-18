import Foundation
import Testing
import WinHubCore
@testable import WinHubRuntime

@Suite struct RecipeRunnerTests {
    final class RecordingExecutor: RecipeExecuting, @unchecked Sendable {
        enum Event: Equatable {
            case runInstaller(String, [String])
            case run(String, [String])
            case addRegistry(String, String, String, String)
            case extractZip(String, String)
            case copyFile(String, String)
        }

        var events: [Event] = []

        func runInstaller(file: URL, arguments: [String]) async throws {
            events.append(.runInstaller(file.lastPathComponent, arguments))
        }

        func run(windowsPath: String, arguments: [String]) async throws {
            events.append(.run(windowsPath, arguments))
        }

        func addRegistry(key: String, value: String, data: String, type: String) async throws {
            events.append(.addRegistry(key, value, data, type))
        }

        func extractZip(_ archive: URL, to destination: URL) async throws {
            events.append(.extractZip(archive.lastPathComponent, destination.path))
        }

        func copyFile(from: URL, to: URL) throws {
            events.append(.copyFile(from.lastPathComponent, to.path))
        }
    }

    private func recipe(_ json: String) throws -> Recipe {
        try JSONDecoder().decode(Recipe.self, from: Data(json.utf8))
    }

    private func bottle(in root: URL) -> Bottle {
        var bottle = Bottle(name: "T", runtimeID: "w")
        bottle.folder = root
        return bottle
    }

    @Test func exeInstallerDoesNotExtract() async throws {
        let json = #"""
        {"bottleName": "T", "installer": {"url": "https://example.invalid/setup.exe", "arguments": ["/S"]},
         "launch": {"windowsPath": "C:\\a.exe"}}
        """#
        let executor = RecordingExecutor()
        let root = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        try await RecipeRunner(executor: executor).applyInstaller(
            try recipe(json), file: root.appending(path: "setup.exe"), in: bottle(in: root))
        #expect(executor.events == [.runInstaller("setup.exe", ["/S"])])
    }

    @Test func zipInstallerExtractsAndDoesNotRun() async throws {
        let json = #"""
        {"bottleName": "T",
         "installer": {"url": "https://example.invalid/app.zip", "extractTo": "Program Files\\App"},
         "launch": {"windowsPath": "C:\\Program Files\\App\\a.exe"}}
        """#
        let executor = RecordingExecutor()
        let root = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let b = bottle(in: root)
        try await RecipeRunner(executor: executor).applyInstaller(
            try recipe(json), file: root.appending(path: "app.zip"), in: b)
        let dest = try #require(b.unixPath(forWindowsPath: #"C:\Program Files\App"#))
        #expect(executor.events == [.extractZip("app.zip", dest.path)])
    }

    @Test func extractsARealZipWithDitto() throws {
        let root = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let payload = root.appending(path: "payload", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: payload, withIntermediateDirectories: true)
        try "hello".write(to: payload.appending(path: "a.txt"), atomically: true, encoding: .utf8)
        let archive = root.appending(path: "app.zip")
        let zip = try ProcessRunner.run(
            URL(fileURLWithPath: "/usr/bin/ditto"),
            arguments: ["-c", "-k", payload.path, archive.path])
        #expect(zip.status == 0)

        let dest = root.appending(path: "out", directoryHint: .isDirectory)
        try ZipExtractor.extract(archive, to: dest)
        let text = try String(contentsOf: dest.appending(path: "a.txt"), encoding: .utf8)
        #expect(text == "hello")
    }
}
