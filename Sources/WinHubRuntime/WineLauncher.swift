import Foundation

public enum WineLauncherError: Error, LocalizedError, Equatable {
    case failed(step: String, status: Int32, log: URL)

    public var errorDescription: String? {
        switch self {
        case .failed(let step, let status, let log):
            "\(step) terminou com erro (código \(status)). Veja o log em \(log.path)."
        }
    }
}

/// Runs Wine commands inside a bottle. Output goes to the bottle's `logs/` folder.
public struct WineLauncher: Sendable {
    public let runtime: InstalledRuntime

    public init(runtime: InstalledRuntime) {
        self.runtime = runtime
    }

    /// Creates the Wine prefix and applies the bottle's Windows version.
    /// Mono and Gecko are skipped here so no download prompts appear; programs
    /// that need them can install them later.
    public func initialize(_ bottle: Bottle) async throws {
        try FileManager.default.createDirectory(at: bottle.prefix, withIntermediateDirectories: true)
        try await runChecked("Criar a garrafa", bottle, ["wineboot", "--init"], logName: "wineboot",
                             extraOverrides: ["mscoree": "", "mshtml": ""])
        try await runChecked("Definir a versão do Windows", bottle,
                             ["winecfg", "/v", bottle.windowsVersion.rawValue], logName: "winecfg")
        try await shutdown(bottle)
    }

    /// Applies `bottle.windowsVersion` to an existing prefix.
    public func applyWindowsVersion(_ bottle: Bottle) async throws {
        try await runChecked("Definir a versão do Windows", bottle,
                             ["winecfg", "/v", bottle.windowsVersion.rawValue], logName: "winecfg")
    }

    /// Runs a `.exe` or `.msi` from the Mac file system and waits for it to finish.
    public func runInstaller(_ bottle: Bottle, file: URL, arguments: [String] = []) async throws {
        let isMSI = file.pathExtension.lowercased() == "msi"
        let args = isMSI ? ["msiexec", "/i", file.path] + arguments : [file.path] + arguments
        try await runChecked("O instalador", bottle, args,
                             logName: "install-\(file.deletingPathExtension().lastPathComponent)")
    }

    /// Opens a Windows shortcut (`.lnk`) found inside the bottle. Returns when it exits.
    @discardableResult
    public func open(_ bottle: Bottle, shortcut: URL) async throws -> Int32 {
        try await run(bottle, ["start", "/wait", "/unix", shortcut.path],
                      logName: shortcut.deletingPathExtension().lastPathComponent)
    }

    /// Runs a program by its Windows path, e.g. `C:\Program Files\App\app.exe`.
    @discardableResult
    public func run(_ bottle: Bottle, windowsPath: String, arguments: [String] = []) async throws -> Int32 {
        let name = windowsPath.split(whereSeparator: { $0 == "\\" || $0 == "/" }).last.map(String.init) ?? "programa"
        return try await run(bottle, [windowsPath] + arguments, logName: name)
    }

    /// Ends every process of the bottle and waits for Wine to save the registry.
    public func shutdown(_ bottle: Bottle) async throws {
        _ = try await ProcessRunner.run(runtime.wineserver, arguments: ["-k"],
                                        environment: environment(for: bottle), log: logURL(bottle, "wineserver"))
        _ = try await ProcessRunner.run(runtime.wineserver, arguments: ["-w"],
                                        environment: environment(for: bottle), log: logURL(bottle, "wineserver"))
    }

    /// Runs `wine <arguments>` and returns its exit status.
    public func run(_ bottle: Bottle, _ arguments: [String], logName: String,
                    extraOverrides: [String: String] = [:]) async throws -> Int32 {
        try await ProcessRunner.run(runtime.wine, arguments: arguments,
                                    environment: environment(for: bottle, extraOverrides: extraOverrides),
                                    log: logURL(bottle, logName))
    }

    public func environment(for bottle: Bottle, extraOverrides: [String: String] = [:]) -> [String: String] {
        WineEnvironment.make(for: bottle, runtime: runtime, extraOverrides: extraOverrides)
    }

    public func logURL(_ bottle: Bottle, _ name: String) -> URL {
        let safe = name.replacingOccurrences(of: "/", with: "-")
        return bottle.logs.appending(path: "\(safe).log")
    }

    private func runChecked(_ step: String, _ bottle: Bottle, _ arguments: [String], logName: String,
                            extraOverrides: [String: String] = [:]) async throws {
        let status = try await run(bottle, arguments, logName: logName, extraOverrides: extraOverrides)
        guard status == 0 else {
            throw WineLauncherError.failed(step: step, status: status, log: logURL(bottle, logName))
        }
    }
}
