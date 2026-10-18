import Foundation
import WinHubCore

public enum RecipeError: Error, LocalizedError, Equatable {
    case zipNeedsDestination
    case extractFailed(status: Int32, log: String)
    case missingPath(String)

    public var errorDescription: String? {
        switch self {
        case .zipNeedsDestination:
            String(localized: "A receita zip precisa de uma pasta de destino (extractTo).")
        case .extractFailed(let status, let log):
            String(localized: "Não foi possível extrair o pacote (código \(status)). \(log)")
        case .missingPath(let path):
            String(localized: "Caminho da receita não encontrado: \(path).")
        }
    }
}

/// Runs the installer and extra steps of a catalog recipe. Tests pass a fake executor;
/// production uses Wine and `ditto`.
public protocol RecipeExecuting: Sendable {
    func runInstaller(file: URL, arguments: [String]) async throws
    func run(windowsPath: String, arguments: [String]) async throws
    func addRegistry(key: String, value: String, data: String, type: String) async throws
    func extractZip(_ archive: URL, to destination: URL) async throws
    func copyFile(from: URL, to: URL) throws
}

/// Unpacks a zip with `/usr/bin/ditto -x -k`.
enum ZipExtractor {
    static func extract(_ archive: URL, to destination: URL) throws {
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        let result = try ProcessRunner.run(
            URL(fileURLWithPath: "/usr/bin/ditto"),
            arguments: ["-x", "-k", archive.path, destination.path])
        guard result.status == 0 else {
            throw RecipeError.extractFailed(status: result.status, log: result.output)
        }
    }
}

public struct RecipeRunner: Sendable {
    public var executor: RecipeExecuting

    public init(executor: RecipeExecuting) {
        self.executor = executor
    }

    /// Runs the recipe's installer: extract a zip, or launch an `.exe`/`.msi`.
    public func applyInstaller(_ recipe: Recipe, file: URL, in bottle: Bottle) async throws {
        switch recipe.installer.resolvedKind {
        case .zip:
            guard let relative = recipe.installer.extractTo, !relative.isEmpty,
                  let destination = Self.unixDestination(extractTo: relative, in: bottle) else {
                throw RecipeError.zipNeedsDestination
            }
            try await executor.extractZip(file, to: destination)
        case .exe, .msi:
            try await executor.runInstaller(file: file, arguments: recipe.installer.arguments)
        }
    }

    /// Extra steps after the installer, in JSON order.
    public func applySteps(_ recipe: Recipe, installerDirectory: URL, in bottle: Bottle) async throws {
        for step in recipe.steps {
            switch step {
            case .run(let windowsPath, let arguments):
                try await executor.run(windowsPath: windowsPath, arguments: arguments)
            case .registry(let key, let value, let data, let type):
                try await executor.addRegistry(key: key, value: value, data: data, type: type)
            case .copy(let from, let to):
                let source = try Self.resolveSource(from, installerDirectory: installerDirectory, bottle: bottle)
                guard let destination = bottle.unixPath(forWindowsPath: to) else {
                    throw RecipeError.missingPath(to)
                }
                try FileManager.default.createDirectory(
                    at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
                if FileManager.default.fileExists(atPath: destination.path) {
                    try FileManager.default.removeItem(at: destination)
                }
                try executor.copyFile(from: source, to: destination)
            }
        }
    }

    /// Installer then extra steps. `installerDirectory` is the folder of the downloaded file.
    public func run(_ recipe: Recipe, file: URL, in bottle: Bottle) async throws {
        try await applyInstaller(recipe, file: file, in: bottle)
        try await applySteps(recipe, installerDirectory: file.deletingLastPathComponent(), in: bottle)
    }

    public func applyRules(_ recipe: Recipe, in bottle: Bottle) throws {
        try CompatRules.apply(recipe.rules, to: bottle)
    }

    /// `extractTo` is a folder under `drive_c`, or a `C:\…` path.
    static func unixDestination(extractTo: String, in bottle: Bottle) -> URL? {
        let trimmed = extractTo.trimmingCharacters(in: .whitespacesAndNewlines)
        let windows = trimmed.lowercased().hasPrefix("c:") ? trimmed : "C:\\" + trimmed
        return bottle.unixPath(forWindowsPath: windows)
    }

    static func isWindowsPath(_ path: String) -> Bool {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        if let drive = trimmed.first, drive.isLetter, trimmed.dropFirst().first == ":" { return true }
        return trimmed.contains("\\")
    }

    static func resolveSource(_ from: String, installerDirectory: URL, bottle: Bottle) throws -> URL {
        if isWindowsPath(from) {
            guard let url = bottle.unixPath(forWindowsPath: from) else { throw RecipeError.missingPath(from) }
            return url
        }
        return installerDirectory.appending(path: from)
    }
}

/// Production executor: Wine for installers, programs and the registry; `ditto` and `FileManager` for files.
public struct WineRecipeExecutor: RecipeExecuting {
    public let launcher: WineLauncher
    public let bottle: Bottle

    public init(launcher: WineLauncher, bottle: Bottle) {
        self.launcher = launcher
        self.bottle = bottle
    }

    public func runInstaller(file: URL, arguments: [String]) async throws {
        try await launcher.runInstaller(bottle, file: file, arguments: arguments)
    }

    public func run(windowsPath: String, arguments: [String]) async throws {
        _ = try await launcher.run(bottle, windowsPath: windowsPath, arguments: arguments)
    }

    public func addRegistry(key: String, value: String, data: String, type: String) async throws {
        let status = try await launcher.run(
            bottle, WineLauncher.registryArguments(key: key, value: value, data: data, type: type), logName: "reg")
        guard status == 0 else {
            throw WineLauncherError.failed(
                step: String(localized: "Registro"), status: status, log: launcher.logURL(bottle, "reg"))
        }
    }

    public func extractZip(_ archive: URL, to destination: URL) async throws {
        try ZipExtractor.extract(archive, to: destination)
    }

    public func copyFile(from: URL, to: URL) throws {
        try FileManager.default.copyItem(at: from, to: to)
    }
}
