import Foundation
import Observation
import WinHubCore

/// Catalog state for the UI: all entries, the current query and the visible results.
@MainActor
@Observable
final class CatalogStore {
    enum Source: Equatable {
        /// The repository's catalog, updated with every commit (see `OfficialData`).
        case official
        case imported(URL)

        var label: String {
            switch self {
            case .official: "Catálogo do WinHub"
            case .imported(let url): url.lastPathComponent
            }
        }
    }

    private(set) var engine = CatalogSearchEngine(entries: [])
    private(set) var result = CatalogSearchEngine(entries: []).search("")
    private(set) var isLoading = false
    private(set) var source: Source = .official
    var errorMessage: String?

    var query = "" { didSet { if query != oldValue { refresh() } } }
    var showUntested = CatalogStore.registeredDefaults.bool(forKey: CatalogStore.showUntestedKey) {
        didSet {
            UserDefaults.standard.set(showUntested, forKey: CatalogStore.showUntestedKey)
            refresh()
        }
    }
    var selection: CatalogEntry.ID?

    static let showUntestedKey = "ShowUntestedApps"

    /// Untested titles are shown unless the user turns them off.
    static var registeredDefaults: UserDefaults {
        UserDefaults.standard.register(defaults: [showUntestedKey: true])
        return .standard
    }

    private static var importedCatalogURL: URL {
        URL.applicationSupportDirectory.appending(path: "WinHub/catalog.json")
    }

    var selectedEntry: CatalogEntry? {
        guard let selection else { return nil }
        return result.entries.first { $0.id == selection }
    }

    func loadInitialCatalog() async {
        if FileManager.default.fileExists(atPath: Self.importedCatalogURL.path) {
            await load(from: Self.importedCatalogURL, source: .imported(Self.importedCatalogURL), persist: false)
        } else {
            await loadOfficial()
        }
    }

    /// Picks up a newly downloaded official catalog, unless the user imported their own.
    func reloadOfficial() async {
        guard source == .official else { return }
        await loadOfficial()
    }

    private func loadOfficial() async {
        let urls = OfficialData.urls(for: OfficialData.catalog)
        for (index, url) in urls.enumerated() {
            if await load(from: url, source: .official, persist: false, reportingErrors: index == urls.count - 1) { return }
        }
    }

    func importCatalog(from url: URL) async {
        selection = nil
        await load(from: url, source: .imported(url), persist: true)
    }

    func resetToOfficial() async {
        try? FileManager.default.removeItem(at: Self.importedCatalogURL)
        selection = nil
        await loadInitialCatalog()
    }

    /// Parses off the main thread, then publishes the results.
    @discardableResult
    private func load(from url: URL, source: Source, persist: Bool, reportingErrors: Bool = true) async -> Bool {
        isLoading = true
        defer { isLoading = false }
        let destination = Self.importedCatalogURL
        do {
            let entries = try await Task.detached(priority: .userInitiated) {
                let accessing = url.startAccessingSecurityScopedResource()
                defer { if accessing { url.stopAccessingSecurityScopedResource() } }
                let entries = try JSONCatalog.load(from: url)
                if persist {
                    try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(),
                                                            withIntermediateDirectories: true)
                    try JSONCatalog.save(entries, to: destination)
                }
                return entries
            }.value
            engine = CatalogSearchEngine(entries: entries)
            self.source = source
            refresh()
            return true
        } catch {
            if reportingErrors { errorMessage = error.localizedDescription }
            return false
        }
    }

    private func refresh() {
        result = engine.search(query, options: .init(showUntested: showUntested))
        if let selection, !result.entries.contains(where: { $0.id == selection }) {
            self.selection = nil
        }
    }
}
