import AppKit
import Foundation
import Observation
import WinHubCore
import WinHubRuntime

/// The data files that follow the repository's `main` branch: a downloaded copy when there is a
/// valid one, otherwise the copy bundled with the app.
enum OfficialData {
    static let catalog = "catalog.json"
    static let runtimes = "runtimes.json"
    static let components = "components.json"

    static let directory = RemoteDataSync.defaultDirectory

    static let files: [RemoteDataSync.File] = [
        .init(name: catalog) { _ = try JSONDecoder().decode([CatalogEntry].self, from: $0) },
        .init(name: runtimes) { data in
            guard try !JSONDecoder().decode([RuntimeManifest].self, from: data).isEmpty else {
                throw CocoaError(.coderValueNotFound)
            }
        },
        .init(name: components) { _ = try JSONDecoder().decode([ComponentManifest].self, from: $0) },
    ]

    /// Downloaded copy first, then the bundled one.
    static func urls(for name: String) -> [URL] {
        let remote = directory.appending(path: name)
        let bundled = Bundle.module.url(forResource: (name as NSString).deletingPathExtension, withExtension: "json")
        return ([FileManager.default.fileExists(atPath: remote.path) ? remote : nil, bundled]).compactMap { $0 }
    }

    static func load<T>(_ name: String, _ decode: (URL) throws -> T) -> T? {
        for url in urls(for: name) {
            if let value = try? decode(url) { return value }
        }
        return nil
    }
}

/// Looks for updates in the GitHub repository: new data on every commit, new app on every release.
@MainActor
@Observable
final class UpdateStore {
    enum Phase: Equatable {
        case idle
        case checking
        case downloading(AppVersion)
        case ready(AppVersion, app: URL, notes: URL)
        case upToDate
        case unavailable(String)
        case failed(String)
    }

    private(set) var phase: Phase = .idle
    private(set) var lastCheck: Date?
    /// Result of a check the user asked for, shown in an alert.
    var notice: String?
    var automaticChecks = UserDefaults.standard.object(forKey: UpdateStore.automaticChecksKey) as? Bool ?? true {
        didSet { UserDefaults.standard.set(automaticChecks, forKey: UpdateStore.automaticChecksKey) }
    }

    static let automaticChecksKey = "AutomaticUpdateChecks"
    static let interval: Duration = .seconds(60 * 60)

    let currentVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String).flatMap(AppVersion.init)
    let repository = Bundle.main.infoDictionary?["WinHubUpdateRepository"] as? String ?? AppUpdater.defaultRepository

    private var isChecking = false
    private var etag: String?
    private var latest: GitHubRelease?
    private var loop: Task<Void, Never>?
    private weak var catalog: CatalogStore?
    private weak var wine: WineStore?

    var readyVersion: AppVersion? {
        if case .ready(let version, _, _) = phase { version } else { nil }
    }

    var statusText: String {
        switch phase {
        case .idle: "Ainda não procurou."
        case .checking: "Procurando…"
        case .downloading(let version): "Baixando a versão \(version)…"
        case .ready(let version, _, _): "A versão \(version) está pronta para instalar."
        case .upToDate: "O WinHub está atualizado."
        case .unavailable(let reason): reason
        case .failed(let message): "Não foi possível procurar atualizações: \(message)"
        }
    }

    /// Checks shortly after launch, then every hour while automatic checks are on.
    func start(catalog: CatalogStore, wine: WineStore) {
        self.catalog = catalog
        self.wine = wine
        guard loop == nil else { return }
        loop = Task { [weak self] in
            try? await Task.sleep(for: .seconds(10))
            while let self, !Task.isCancelled {
                if self.automaticChecks { await self.check() }
                try? await Task.sleep(for: Self.interval)
            }
        }
    }

    func check(userInitiated: Bool = false) async {
        guard !isChecking else { return }
        isChecking = true
        defer { isChecking = false }
        await syncData()
        await checkApp()
        lastCheck = .now
        // A ready update shows up in the sidebar; anything else is reported here.
        if userInitiated, readyVersion == nil { notice = statusText }
    }

    private func syncData() async {
        let sync = RemoteDataSync(baseURL: RemoteDataSync.baseURL(repository: repository), directory: OfficialData.directory)
        let changed = await sync.sync(OfficialData.files)
        if changed.contains(OfficialData.catalog) { await catalog?.reloadOfficial() }
        if !changed.isDisjoint(with: [OfficialData.runtimes, OfficialData.components]) { wine?.reloadManifests() }
    }

    private func checkApp() async {
        let bundle = Bundle.main.bundleURL
        guard let currentVersion, bundle.pathExtension == "app" else {
            phase = .unavailable("O app só se atualiza sozinho quando empacotado (WinHub.app).")
            return
        }
        guard AppUpdater.canReplace(bundle) else {
            phase = .unavailable("Mova o WinHub para a pasta Aplicativos para que ele se atualize sozinho.")
            return
        }
        if readyVersion == nil { phase = .checking }
        let updater = AppUpdater(repository: repository)
        do {
            if case .release(let release, let etag) = try await updater.latestRelease(etag: etag) {
                latest = release
                self.etag = etag
            }
            guard let release = latest, let version = release.version, version > currentVersion,
                  release.appAsset != nil else {
                phase = .upToDate
                return
            }
            if readyVersion == version { return }
            phase = .downloading(version)
            let app = try await Task.detached(priority: .utility) {
                try await updater.stage(release, current: bundle)
            }.value
            phase = .ready(version, app: app, notes: release.pageURL)
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    /// Quits and lets a small script swap the app and open the new one.
    func restartToUpdate() {
        guard case .ready(_, let app, _) = phase else { return }
        do {
            try AppUpdater.install(app, over: Bundle.main.bundleURL, pid: ProcessInfo.processInfo.processIdentifier)
            NSApp.terminate(nil)
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}
