import AppKit
import Foundation
import Observation
import WinHubCore
import WinHubRuntime

/// App state for running Windows programs: the Wine runtime, bottles,
/// installed programs and the work in progress.
@MainActor
@Observable
final class WineStore {
    /// A `.exe`/`.msi` the user picked, waiting for a bottle choice.
    struct PendingInstall: Identifiable {
        let id = UUID()
        var file: URL
        var bottleID: Bottle.ID?
    }

    private(set) var manifests: [RuntimeManifest] = []
    private(set) var components: [ComponentManifest] = []
    private(set) var runtime: InstalledRuntime?
    /// 0…1 while the runtime downloads; `nil` otherwise.
    private(set) var runtimeProgress: Double?
    private(set) var bottles: [Bottle] = []
    private(set) var programs: [Bottle.ID: [InstalledProgram]] = [:]
    /// What is happening right now, keyed by bottle id or catalog entry id.
    private(set) var activity: [String: String] = [:]
    /// Bottles with Wine processes running (checked every few seconds).
    private(set) var activeBottles: Set<Bottle.ID> = []

    var errorMessage: String?
    var isShowingRuntimeSetup = false
    var pendingInstall: PendingInstall?

    private let runtimeManager = RuntimeManager(root: RuntimeManager.defaultRoot)
    private let bottleStore = BottleStore(root: BottleStore.defaultRoot)
    private let downloader = Downloader(directory: Downloader.defaultDirectory)
    private let launchers = AppLauncherBuilder(root: AppLauncherBuilder.defaultRoot)
    private let componentManager = ComponentManager(root: ComponentManager.defaultRoot)
    /// In the packaged app's resources; `swift run` needs `WINHUB_STEAMWEBHELPER_WRAPPER`.
    private let steamWrapper = SteamWebHelperWrapper.locate(
        bundled: Bundle.main.url(forResource: "steamwebhelper-wrapper", withExtension: "exe"))

    init() {
        reloadManifests()
        Task { [weak self] in
            while let self {
                self.updateActiveBottles()
                try? await Task.sleep(for: .seconds(3))
            }
        }
    }

    private func updateActiveBottles() {
        let active = Set(bottles.filter { WineServerStatus.isRunning(prefix: $0.prefix) }.map(\.id))
        if active != activeBottles { activeBottles = active }
    }

    var manifest: RuntimeManifest? { manifests.first }
    private(set) var isRosettaAvailable = RuntimeManager.isRosettaAvailable
    private(set) var isInstallingRosetta = false

    /// Backends the installed runtime can use (DXMT needs a build made for it; "automatic" and
    /// D3DMetal need an engine that picks the Direct3D itself, D3DMetal also the user's copy of it).
    var graphicsBackends: [GraphicsBackend] {
        let dispatches = runtime?.dispatchesGraphics == true
        return GraphicsBackend.allCases.filter { backend in
            switch backend {
            case .auto: dispatches
            case .d3dmetal: dispatches && D3DMetal.installed(at: d3dmetalLocation) != nil
            case .dxmt: runtime?.manifest.supports(.dxmt) == true
            case .dxvk: !dispatches || runtime?.manifest.supports(.dxvk) == true
            case .wined3d: true
            }
        }
    }
    var supportsMSync: Bool { runtime?.manifest.supports(.msync) == true }
    var supportsNVIDIAExtensions: Bool { runtime?.manifest.supports(.nvext) == true }
    /// winetricks finds `cabextract` only when the manifests offer it.
    var hasCabextract: Bool { component(named: "cabextract") != nil }

    func installRosetta() async {
        guard !isInstallingRosetta else { return }
        isInstallingRosetta = true
        defer { isInstallingRosetta = false }
        do {
            try await Task.detached(priority: .userInitiated) { try RuntimeManager.installRosetta() }.value
        } catch {
            errorMessage = error.localizedDescription
        }
        isRosettaAvailable = RuntimeManager.isRosettaAvailable
    }

    /// A newer Wine than the installed one (the manifests follow the repository).
    var runtimeUpgrade: RuntimeManifest? {
        guard let runtime, let manifest, !runtime.manifest.isSameBuild(as: manifest) else { return nil }
        return manifest
    }

    /// Reads the manifests: the copy downloaded from the repository, else the bundled one.
    func reloadManifests() {
        manifests = OfficialData.load(OfficialData.runtimes) { url in
            let all = try RuntimeManifest.loadAll(from: url)
            guard !all.isEmpty else { throw CocoaError(.coderValueNotFound) }
            return all
        } ?? []
        components = OfficialData.load(OfficialData.components, ComponentManifest.loadAll) ?? []
        refresh()
    }

    func refresh() {
        // An older Wine keeps working until the user installs the new one.
        runtime = manifest.flatMap(runtimeManager.installed) ?? runtimeManager.installedRuntimes().first
        bottles = bottleStore.list()
        programs = Dictionary(uniqueKeysWithValues: bottles.map { ($0.id, ProgramScanner.programs(in: $0)) })
        updateActiveBottles()
    }

    func bottle(id: Bottle.ID?) -> Bottle? { bottles.first { $0.id == id } }
    func bottle(named name: String) -> Bottle? {
        bottles.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }

    // MARK: Runtime

    func installRuntime() async {
        guard let manifest, runtimeProgress == nil else { return }
        runtimeProgress = 0
        defer { runtimeProgress = nil }
        do {
            let manager = runtimeManager
            let report: @Sendable (Double) -> Void = { [weak self] value in
                Task { @MainActor in self?.runtimeProgress = value }
            }
            runtime = try await Task.detached(priority: .userInitiated) {
                try await manager.install(manifest, progress: report)
            }.value
            isShowingRuntimeSetup = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// The installed runtime, or `nil` after asking the user to download it.
    private func requireRuntime() -> InstalledRuntime? {
        if runtime == nil { isShowingRuntimeSetup = true }
        return runtime
    }

    // MARK: Bottles

    @discardableResult
    func createBottle(name: String, windowsVersion: Bottle.WindowsVersion = .win10) async -> Bottle? {
        guard let runtime = requireRuntime() else { return nil }
        do {
            let bottle = try bottleStore.create(name: name, runtimeID: runtime.manifest.id, windowsVersion: windowsVersion,
                                                graphics: runtime.dispatchesGraphics ? .auto : .wined3d)
            refresh()
            try await perform(key: bottle.id.uuidString, "Criando a garrafa…") {
                try await WineLauncher(runtime: runtime).initialize(bottle)
            }
            refresh()
            return bottle
        } catch {
            errorMessage = error.localizedDescription
            refresh()
            return nil
        }
    }

    func setWindowsVersion(_ version: Bottle.WindowsVersion, for bottle: Bottle) async {
        guard let runtime = requireRuntime() else { return }
        var updated = bottle
        updated.windowsVersion = version
        do {
            try bottleStore.save(updated)
            refresh()
            try await perform(key: bottle.id.uuidString, "Aplicando \(version.title)…") {
                try await WineLauncher(runtime: runtime).applyWindowsVersion(updated)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func shutdown(_ bottle: Bottle) async {
        guard let runtime else { return }
        try? await perform(key: bottle.id.uuidString, "Encerrando os programas…") {
            try await WineLauncher(runtime: runtime).shutdown(bottle)
        }
    }

    func delete(_ bottle: Bottle) async {
        await shutdown(bottle)
        do {
            try launchers.removeAll(for: bottle)
            try bottleStore.delete(bottle)
        } catch {
            errorMessage = error.localizedDescription
        }
        refresh()
    }

    func revealDriveC(_ bottle: Bottle) {
        NSWorkspace.shared.activateFileViewerSelecting([bottle.driveC])
    }

    func revealLogs(_ bottle: Bottle) {
        try? FileManager.default.createDirectory(at: bottle.logs, withIntermediateDirectories: true)
        NSWorkspace.shared.open(bottle.logs)
    }

    // MARK: Graphics and components

    private func component(named name: String) -> ComponentManifest? {
        components.first { $0.name == name }
    }

    /// Downloads a component if needed (small, checked by SHA-256).
    private func ensureComponent(named name: String, key: String) async throws -> InstalledComponent {
        guard let manifest = component(named: name) else {
            throw RuntimeError.missingBinary(URL(fileURLWithPath: name))
        }
        if let installed = componentManager.installed(manifest) { return installed }
        let manager = componentManager
        return try await perform(key: key, "Baixando \(manifest.name) \(manifest.version)…") {
            try await Task.detached { try await manager.install(manifest) }.value
        }
    }

    func setGraphics(_ backend: GraphicsBackend, for bottle: Bottle) async {
        guard let runtime = requireRuntime() else { return }
        do {
            // Engines that pick the Direct3D themselves bring DXVK; older ones copy the DXVK-macOS component.
            let dxvk = backend == .dxvk && !runtime.dispatchesGraphics
                ? try await ensureComponent(named: "DXVK-macOS", key: bottle.id.uuidString) : nil
            let updated = try WineLauncher(runtime: runtime).applyGraphics(backend, to: bottle, dxvk: dxvk)
            try bottleStore.save(updated)
            refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Gives one program its own Direct3D (`nil`: back to the bottle's setting).
    func setProgramGraphics(_ backend: GraphicsBackend?, program: String, in bottle: Bottle) async {
        guard let runtime = requireRuntime() else { return }
        let key = bottle.id.uuidString
        do {
            let dxvk = runtime.dispatchesGraphics ? nil
                : backend == .dxvk ? try await ensureComponent(named: "DXVK-macOS", key: key)
                : component(named: "DXVK-macOS").flatMap(componentManager.installed)
            let updated = try await perform(key: key, "Aplicando os gráficos do programa…") {
                try await WineLauncher(runtime: runtime).applyProgramGraphics(backend, program: program, in: bottle, dxvk: dxvk)
            }
            try bottleStore.save(updated)
        } catch {
            errorMessage = error.localizedDescription
        }
        refresh()
    }

    /// Asks for a `.exe` inside the bottle (Steam's game folder first) and gives it the
    /// fastest Direct3D available.
    func chooseProgramForGraphics(in bottle: Bottle) async {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.exe].compactMap { $0 }
        panel.message = "Escolha o .exe do programa ou do jogo"
        let steamGames = bottle.driveC.appending(path: "Program Files (x86)/Steam/steamapps/common", directoryHint: .isDirectory)
        panel.directoryURL = FileManager.default.fileExists(atPath: steamGames.path) ? steamGames : bottle.driveC
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let program = bottle.windowsPath(forUnixPath: url) else {
            errorMessage = "Escolha um programa que esteja dentro do disco C: da garrafa “\(bottle.name)”."
            return
        }
        await setProgramGraphics(graphicsBackends.contains(.dxmt) ? .dxmt : .dxvk, program: program, in: bottle)
    }

    /// Where WinHub looks for Apple's D3DMetal; observed by the settings.
    private(set) var d3dmetalLocation = D3DMetal.location
    var hasD3DMetal: Bool { D3DMetal.installed(at: d3dmetalLocation) != nil }
    var usesDefaultD3DMetalFolder: Bool { d3dmetalLocation == D3DMetal.defaultLocation }

    /// Asks for the user's Game Porting Toolkit folder (WinHub never ships D3DMetal).
    func chooseD3DMetalFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.message = "Escolha a pasta do Game Porting Toolkit da Apple (ou a pasta redist/lib dele)"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let found = D3DMetal.resolve(url) else {
            errorMessage = "Não há D3DMetal em “\(url.lastPathComponent)”. Escolha a pasta do Game Porting Toolkit ou a pasta redist/lib dele."
            return
        }
        if found.path.hasPrefix("/Volumes/") {
            errorMessage = "O D3DMetal está num disco (\(found.path)). Ele só funciona enquanto esse disco estiver montado; copie a pasta lib para o Mac para usar sempre."
        }
        D3DMetal.location = found
        d3dmetalLocation = found
    }

    func useDefaultD3DMetalFolder() {
        D3DMetal.location = D3DMetal.defaultLocation
        d3dmetalLocation = D3DMetal.defaultLocation
    }

    /// Changing msync while the bottle runs means closing its programs first (see `setMSync`).
    func msyncChangeClosesPrograms(_ enabled: Bool, for bottle: Bottle) -> Bool {
        var updated = bottle
        updated.msync = enabled
        guard let runtime, activeBottles.contains(bottle.id) else { return false }
        return WineEnvironment.needsServerRestart(from: bottle, to: updated, runtime: runtime)
    }

    /// ntdll refuses new processes whose `WINEMSYNC` differs from the running wineserver's, so a
    /// running bottle is ended (with its current settings) before the change is saved.
    func setMSync(_ enabled: Bool, for bottle: Bottle) async {
        var updated = bottle
        updated.msync = enabled
        if msyncChangeClosesPrograms(enabled, for: bottle), let runtime {
            try? await perform(key: bottle.id.uuidString, "Encerrando a garrafa para aplicar…") {
                try await WineLauncher(runtime: runtime).shutdown(bottle)
            }
            updateActiveBottles()
        }
        save(updated)
    }

    /// Display modes are cached by the bottle's running processes, so a running bottle is ended first.
    func setExtraDisplayModes(_ enabled: Bool, for bottle: Bottle) async {
        guard let runtime else { return }
        var updated = bottle
        updated.extraDisplayModes = enabled
        do {
            try await perform(key: bottle.id.uuidString, "Aplicando as resoluções…") {
                let launcher = WineLauncher(runtime: runtime)
                if activeBottles.contains(bottle.id) {
                    try await launcher.shutdown(bottle)
                    updateActiveBottles()
                }
                try await launcher.applyDisplayModes(updated)
            }
            save(updated)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setNVIDIAExtensions(_ enabled: Bool, for bottle: Bottle) {
        var updated = bottle
        updated.nvidiaExtensions = enabled
        save(updated)
    }

    func setPerformanceHUD(_ enabled: Bool, for bottle: Bottle) {
        var updated = bottle
        updated.performanceHUD = enabled
        save(updated)
    }

    /// Settings that only change the environment apply the next time a program opens.
    private func save(_ bottle: Bottle) {
        do {
            try bottleStore.save(bottle)
        } catch {
            errorMessage = error.localizedDescription
        }
        refresh()
    }

    /// Installs winetricks verbs such as `vcrun2022` or `corefonts` into a bottle.
    func installDependencies(_ verbs: [String], in bottle: Bottle, key: String? = nil) async throws {
        guard !verbs.isEmpty, let runtime = requireRuntime() else { return }
        let key = key ?? bottle.id.uuidString
        let winetricks = try await ensureComponent(named: "winetricks", key: key)
        let cabextract = hasCabextract ? try await ensureComponent(named: "cabextract", key: key) : nil
        try await perform(key: key, "Instalando \(verbs.joined(separator: ", "))…") {
            try await WineLauncher(runtime: runtime).runWinetricks(verbs, in: bottle, winetricks: winetricks,
                                                                   cabextract: cabextract)
        }
    }

    func installDependenciesFromUI(_ text: String, in bottle: Bottle) async {
        let verbs = text.split(whereSeparator: { $0 == " " || $0 == "," }).map(String.init)
        do {
            try await installDependencies(verbs, in: bottle)
        } catch {
            errorMessage = error.localizedDescription
        }
        refresh()
    }

    // MARK: Launchers

    func hasLauncher(for program: InstalledProgram, in bottle: Bottle) -> Bool {
        launchers.exists(for: program, in: bottle)
    }

    /// Creates `~/Applications/WinHub/<garrafa>/<programa>.app` and shows it in Finder.
    func createLauncher(for program: InstalledProgram, in bottle: Bottle) {
        do {
            let app = try launchers.create(for: program, in: bottle)
            refresh()
            NSWorkspace.shared.activateFileViewerSelecting([app])
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func revealLauncher(for program: InstalledProgram, in bottle: Bottle) {
        NSWorkspace.shared.activateFileViewerSelecting([launchers.launcherURL(for: program, in: bottle)])
    }

    // MARK: Installing

    /// Asks for a `.exe`/`.msi`; the root view then shows the bottle choice.
    func chooseInstaller(into bottleID: Bottle.ID? = nil) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.exe, .msi].compactMap { $0 }
        panel.allowsOtherFileTypes = true
        panel.message = "Escolha o instalador do Windows (.exe ou .msi)"
        if panel.runModal() == .OK, let url = panel.url {
            pendingInstall = PendingInstall(file: url, bottleID: bottleID)
        }
    }

    /// Runs a user-chosen installer in an existing bottle or a new one.
    func installUnlisted(_ file: URL, into existing: Bottle?, newBottleName: String,
                         windowsVersion: Bottle.WindowsVersion) async {
        guard requireRuntime() != nil else { return }
        var target = existing
        if target == nil {
            target = await createBottle(name: newBottleName, windowsVersion: windowsVersion)
        }
        guard let bottle = target, let runtime else { return }
        do {
            try await perform(key: bottle.id.uuidString, "Instalando \(file.lastPathComponent)…") {
                try await WineLauncher(runtime: runtime).runInstaller(bottle, file: file)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        refresh()
    }

    func isInstalled(_ recipe: Recipe) -> Bool {
        guard let bottle = bottle(named: recipe.bottleName),
              let program = bottle.unixPath(forWindowsPath: recipe.launch.windowsPath) else { return false }
        return FileManager.default.fileExists(atPath: program.path)
    }

    /// Creates or reuses the recipe's bottle, downloads the installer, runs it, then opens the program.
    func install(_ recipe: Recipe, entryID: String) async {
        guard let runtime = requireRuntime() else { return }
        let version = Bottle.WindowsVersion(rawValue: recipe.windowsVersion) ?? .win10
        do {
            var bottle = bottle(named: recipe.bottleName)
            if bottle == nil {
                activity[entryID] = "Criando a garrafa “\(recipe.bottleName)”…"
                bottle = await createBottle(name: recipe.bottleName, windowsVersion: version)
            }
            guard let bottle else { activity[entryID] = nil; return }

            try await installDependencies(recipe.dependencies, in: bottle, key: entryID)
            let installer = try await perform(key: entryID, "Baixando o instalador…") {
                try await self.downloader.download(recipe.installer.url, fileName: recipe.installer.fileName,
                                                   sha256: recipe.installer.sha256)
            }
            try await perform(key: entryID, "Instalando…") {
                try await WineLauncher(runtime: runtime).runInstaller(bottle, file: installer,
                                                                    arguments: recipe.installer.arguments)
            }
            refresh()
            guard isInstalled(recipe) else {
                errorMessage = "O instalador terminou, mas o programa não foi encontrado em \(recipe.launch.windowsPath)."
                return
            }
            open(recipe)
        } catch {
            activity[entryID] = nil
            errorMessage = error.localizedDescription
        }
    }

    // MARK: Opening

    /// Handles `winhub://open?bottle=<id>&shortcut=<path>`, used by the launchers in
    /// ~/Applications/WinHub. Only shortcuts that exist inside that bottle's C: drive
    /// are opened, so a link cannot run arbitrary files.
    func handle(_ url: URL) {
        guard url.scheme == "winhub", url.host() == "open",
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
              let id = items.first(where: { $0.name == "bottle" })?.value.flatMap(UUID.init(uuidString:)),
              let path = items.first(where: { $0.name == "shortcut" })?.value else { return }
        refresh()
        guard let bottle = bottle(id: id) else {
            errorMessage = "A garrafa deste atalho não existe mais."
            return
        }
        let shortcut = URL(fileURLWithPath: path).standardizedFileURL
        guard shortcut.path.hasPrefix(bottle.driveC.standardizedFileURL.path + "/"),
              let program = programs[bottle.id]?.first(where: { $0.shortcut.standardizedFileURL == shortcut }) else {
            errorMessage = "O programa deste atalho não foi encontrado na garrafa “\(bottle.name)”."
            return
        }
        open(program, in: bottle)
    }

    func open(_ recipe: Recipe) {
        guard let bottle = bottle(named: recipe.bottleName) else { return }
        let arguments = SteamClient.arguments(forOpening: recipe.launch.windowsPath, recipe.launch.arguments,
                                              wrapperInstalled: prepareSteam(in: bottle))
        launch(in: bottle) { launcher in
            try await launcher.run(bottle, windowsPath: recipe.launch.windowsPath, arguments: arguments)
        }
    }

    func open(_ program: InstalledProgram, in bottle: Bottle) {
        let wrapperInstalled = prepareSteam(in: bottle)
        let arguments = SteamClient.isClientShortcut(named: program.name)
            ? SteamClient.launchArguments(wrapperInstalled: wrapperInstalled) : []
        launch(in: bottle) { launcher in
            try await launcher.open(bottle, shortcut: program.shortcut, arguments: arguments)
        }
    }

    /// Opens a Steam game through the Steam client bottle.
    func playOnSteam(appID: Int) {
        guard let bottle = bottle(named: SteamClient.bottleName) else { return }
        let arguments = SteamClient.runArguments(appID: appID, wrapperInstalled: prepareSteam(in: bottle))
        launch(in: bottle) { launcher in
            try await launcher.run(bottle, windowsPath: SteamClient.windowsPath, arguments: arguments)
        }
    }

    /// Recommended Direct3D for a Steam game, if this runtime has it.
    func recommendedGraphics(for game: CatalogEntry.SteamGame) -> GraphicsBackend? {
        game.graphics.flatMap(GraphicsBackend.init(rawValue:)).flatMap { graphicsBackends.contains($0) ? $0 : nil }
    }

    /// The game is installed in the Steam bottle.
    func isInstalled(_ game: CatalogEntry.SteamGame) -> Bool {
        guard let bottle = bottle(named: SteamClient.bottleName),
              let exe = bottle.unixPath(forWindowsPath: game.windowsPath) else { return false }
        return FileManager.default.fileExists(atPath: exe.path)
    }

    func graphics(for game: CatalogEntry.SteamGame) -> GraphicsBackend? {
        bottle(named: SteamClient.bottleName)?.programGraphics[game.windowsPath]
    }

    func applyRecommendedGraphics(_ game: CatalogEntry.SteamGame) async {
        guard let bottle = bottle(named: SteamClient.bottleName), let backend = recommendedGraphics(for: game) else { return }
        await setProgramGraphics(backend, program: game.windowsPath, in: bottle)
    }

    var isSteamInstalled: Bool {
        guard let bottle = bottle(named: SteamClient.bottleName),
              let steam = bottle.unixPath(forWindowsPath: SteamClient.windowsPath) else { return false }
        return FileManager.default.fileExists(atPath: steam.path)
    }

    /// Puts the Steam wrapper in place (see `SteamWebHelperWrapper`). Returns whether it
    /// is installed, i.e. whether Steam must be told to skip its file check.
    private func prepareSteam(in bottle: Bottle) -> Bool {
        do {
            return try steamWrapper?.install(in: bottle) ?? false
        } catch {
            errorMessage = "Não foi possível preparar a janela da Steam: \(error.localizedDescription)"
            return false
        }
    }

    /// Starts a program and returns immediately. Programs may restart
    /// themselves (Steam does after updating), so "running" is tracked per bottle.
    private func launch(in bottle: Bottle, _ body: @escaping @Sendable (WineLauncher) async throws -> Int32) {
        guard let runtime = requireRuntime() else { return }
        activeBottles.insert(bottle.id)
        Task {
            do {
                let launcher = WineLauncher(runtime: runtime)
                // A new wineserver reuses the prefix's folder; clear what an earlier one left behind.
                await launcher.reapOrphans(bottle)
                // Bottles set up when DXVK/DXMT were copied into them, now with an engine that picks it.
                if let migrated = try await launcher.migrateToDispatchedGraphics(bottle) { try bottleStore.save(migrated) }
                _ = try await body(launcher)
            } catch {
                errorMessage = error.localizedDescription
            }
            refresh()
        }
    }

    /// Shows `message` under `key` while `work` runs.
    @discardableResult
    private func perform<T>(key: String, _ message: String, _ work: @MainActor () async throws -> T) async throws -> T {
        activity[key] = message
        defer { activity[key] = nil }
        return try await work()
    }
}

import UniformTypeIdentifiers

extension UTType {
    static let exe = UTType(filenameExtension: "exe")
    static let msi = UTType(filenameExtension: "msi")
}
