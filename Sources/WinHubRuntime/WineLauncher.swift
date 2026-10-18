import Foundation

public enum WineLauncherError: Error, LocalizedError, Equatable {
    case failed(step: String, status: Int32, log: URL)

    public var errorDescription: String? {
        switch self {
        case .failed(let step, let status, let log):
            String(localized: "\(step) terminou com erro (código \(status)). Veja o log em \(log.path).")
        }
    }
}

/// Wine's own programs, opened from a bottle's page.
public enum WineTool: String, CaseIterable, Sendable {
    case configuration, registryEditor, controlPanel, taskManager, commandPrompt

    public var title: String {
        switch self {
        case .configuration: String(localized: "Configuração do Wine")
        case .registryEditor: String(localized: "Editor do Registro")
        case .controlPanel: String(localized: "Painel de Controle")
        case .taskManager: String(localized: "Gerenciador de Tarefas")
        case .commandPrompt: String(localized: "Prompt de Comando")
        }
    }

    public var systemImage: String {
        switch self {
        case .configuration: "gearshape"
        case .registryEditor: "list.bullet.rectangle"
        case .controlPanel: "slider.horizontal.3"
        case .taskManager: "chart.bar"
        case .commandPrompt: "terminal"
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
        try await runChecked(String(localized: "Criar a garrafa"), bottle, ["wineboot", "--init"], logName: "wineboot",
                             extraOverrides: ["mscoree": "", "mshtml": ""])
        try await runChecked(String(localized: "Definir a versão do Windows"), bottle,
                             ["winecfg", "/v", bottle.windowsVersion.rawValue], logName: "winecfg")
        try await shutdown(bottle)
    }

    /// Applies `bottle.windowsVersion` to an existing prefix.
    public func applyWindowsVersion(_ bottle: Bottle) async throws {
        try await runChecked(String(localized: "Definir a versão do Windows"), bottle,
                             ["winecfg", "/v", bottle.windowsVersion.rawValue], logName: "winecfg")
    }

    /// Applies `bottle.extraDisplayModes` (`EmulateModeset`, read by win32u whatever the driver).
    /// The bottle's desktop process lists the display modes for every program and reads the setting
    /// when it starts, so the session `reg` itself started (with the old value) is ended afterwards.
    /// Programs already running keep the modes they saw; close the bottle first.
    public func applyDisplayModes(_ bottle: Bottle) async throws {
        try await runChecked(String(localized: "Mudar as resoluções da garrafa"), bottle,
                             Self.displayModesArguments(bottle.extraDisplayModes), logName: "reg")
        try await shutdown(bottle)
    }

    /// `cmd` is a console program and needs a window of its own; `start` opens one.
    public static func toolArguments(_ tool: WineTool) -> [String] {
        switch tool {
        case .configuration: ["winecfg"]
        case .registryEditor: ["regedit"]
        case .controlPanel: ["control"]
        case .taskManager: ["taskmgr"]
        case .commandPrompt: ["start", "cmd"]
        }
    }

    /// Runs any program from the Mac file system once: `.msi` through msiexec, the rest through `start /unix`
    /// (which also handles `.bat`, `.cmd` and `.com`). `workingDirectory` is a Windows path.
    static func commandArguments(file: URL, arguments: [String], workingDirectory: String?) -> [String] {
        if file.pathExtension.lowercased() == "msi" { return ["msiexec", "/i", file.path] + arguments }
        return ["start", "/wait"] + (workingDirectory.map { ["/d", $0] } ?? []) + ["/unix", file.path] + arguments
    }

    /// Runs `file` with `arguments`, in `workingDirectory` and with `environment` on top of the bottle's.
    @discardableResult
    public func runCommand(_ bottle: Bottle, file: URL, arguments: [String] = [], workingDirectory: String? = nil,
                           environment: [String: String] = [:]) async throws -> Int32 {
        try await run(bottle, Self.commandArguments(file: file, arguments: arguments, workingDirectory: workingDirectory),
                      logName: file.deletingPathExtension().lastPathComponent, extraEnvironment: environment)
    }

    static func displayModesArguments(_ enabled: Bool) -> [String] {
        ["reg", "add", #"HKCU\Software\Wine\X11 Driver"#, "/v", "EmulateModeset", "/d", enabled ? "Y" : "N", "/f"]
    }

    static func registryArguments(key: String, value: String, data: String, type: String) -> [String] {
        ["reg", "add", key, "/v", value, "/d", data, "/t", type, "/f"]
    }

    /// Runs a `.exe` or `.msi` from the Mac file system and waits for it to finish.
    public func runInstaller(_ bottle: Bottle, file: URL, arguments: [String] = []) async throws {
        let isMSI = file.pathExtension.lowercased() == "msi"
        let args = isMSI ? ["msiexec", "/i", file.path] + arguments : [file.path] + arguments
        try await runChecked(String(localized: "O instalador"), bottle, args,
                             logName: "install-\(file.deletingPathExtension().lastPathComponent)")
    }

    /// Opens a Windows shortcut (`.lnk`) found inside the bottle. Returns when it exits.
    /// `arguments` are passed to the program after the shortcut's own.
    @discardableResult
    public func open(_ bottle: Bottle, shortcut: URL, arguments: [String] = []) async throws -> Int32 {
        try await run(bottle, Self.shortcutArguments(shortcut, arguments),
                      logName: shortcut.deletingPathExtension().lastPathComponent)
    }

    static func shortcutArguments(_ shortcut: URL, _ arguments: [String]) -> [String] {
        ["start", "/wait", "/unix", shortcut.path] + arguments
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
        // `-k` only reaches the clients of the current wineserver, not those of an earlier one that died.
        await reapOrphans(bottle)
    }

    /// Ends the bottle's programs even when its wineserver was started by another engine. `-k` works across
    /// engine versions (it goes through the lock file and signals) and ends the server, whichever engine
    /// started it; unlike `shutdown`, it does not wait with `-w`. It can take a while (about 10 s) because it
    /// signals the server and escalates. `ProcessTerminator` is the fallback for when this engine's
    /// `wineserver` cannot run or the server outlives `-k`: SIGTERM, then SIGKILL. Leftover clients are reaped.
    public func forceShutdown(_ bottle: Bottle) async {
        if let pid = WineServerStatus.serverPID(prefix: bottle.prefix) {
            _ = try? await ProcessRunner.run(runtime.wineserver, arguments: ["-k"],
                                             environment: environment(for: bottle), log: logURL(bottle, "wineserver"))
            await ProcessTerminator.end(pid, grace: .seconds(5))
        }
        await reapOrphans(bottle)
    }

    /// Ends processes left behind by a wineserver of this bottle that is gone
    /// (see `WineOrphanReaper`). Does nothing while the bottle's wineserver runs.
    @discardableResult
    public func reapOrphans(_ bottle: Bottle) async -> [pid_t] {
        let pids = WineOrphanReaper.reap(prefix: bottle.prefix)
        if !pids.isEmpty {
            let line = "WinHub: ended orphaned Wine processes (wineserver gone): \(pids.map(String.init).joined(separator: " "))\n"
            appendLog(bottle, "wineserver", line)
        }
        return pids
    }

    /// Runs `wine <arguments>` and returns its exit status.
    public func run(_ bottle: Bottle, _ arguments: [String], logName: String,
                    extraOverrides: [String: String] = [:], extraEnvironment: [String: String] = [:]) async throws -> Int32 {
        try await ProcessRunner.run(runtime.wine, arguments: arguments,
                                    environment: environment(for: bottle, extraOverrides: extraOverrides,
                                                             extraEnvironment: extraEnvironment),
                                    log: logURL(bottle, logName))
    }

    /// `extraEnvironment` is merged last, so it wins over the bottle's own variables.
    public func environment(for bottle: Bottle, extraOverrides: [String: String] = [:],
                            extraEnvironment: [String: String] = [:]) -> [String: String] {
        WineEnvironment.make(for: bottle, runtime: runtime, extraOverrides: extraOverrides,
                             d3dmetal: runtime.dispatchesGraphics ? D3DMetal.installed() : nil)
            .merging(extraEnvironment) { _, extra in extra }
    }

    public func logURL(_ bottle: Bottle, _ name: String) -> URL {
        let safe = name.replacingOccurrences(of: "/", with: "-")
        return bottle.logs.appending(path: "\(safe).log")
    }

    private func appendLog(_ bottle: Bottle, _ name: String, _ text: String) {
        let url = logURL(bottle, name)
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: url.path) { FileManager.default.createFile(atPath: url.path, contents: nil) }
        guard let handle = try? FileHandle(forWritingTo: url) else { return }
        defer { try? handle.close() }
        _ = try? handle.seekToEnd()
        try? handle.write(contentsOf: Data(text.utf8))
    }

    private func runChecked(_ step: String, _ bottle: Bottle, _ arguments: [String], logName: String,
                            extraOverrides: [String: String] = [:]) async throws {
        let status = try await run(bottle, arguments, logName: logName, extraOverrides: extraOverrides)
        guard status == 0 else {
            throw WineLauncherError.failed(step: step, status: status, log: logURL(bottle, logName))
        }
    }
}
