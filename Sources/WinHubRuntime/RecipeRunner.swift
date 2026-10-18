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

    /// `extractTo` is a folder under `drive_c`, or a `C:\…` path.
    static func unixDestination(extractTo: String, in bottle: Bottle) -> URL? {
        let trimmed = extractTo.trimmingCharacters(in: .whitespacesAndNewlines)
        let windows = trimmed.lowercased().hasPrefix("c:") ? trimmed : "C:\\" + trimmed
        return bottle.unixPath(forWindowsPath: windows)
    }
}
