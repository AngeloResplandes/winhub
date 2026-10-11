import Foundation
import Observation
import WinHubCore

/// Catalog state for the UI: all entries, the current query and the visible results.
@MainActor
@Observable
final class CatalogStore {
    enum Source: Equatable {
        case sample
        case imported(URL)

        var label: String {
            switch self {
            case .sample: "Catálogo de exemplo"
            case .imported(let url): url.lastPathComponent
            }
        }
    }

    private(set) var engine = CatalogSearchEngine(entries: [])
    private(set) var result = CatalogSearchEngine(entries: []).search("")
    private(set) var isLoading = false
    private(set) var source: Source = .sample
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
        } else if let sample = Bundle.module.url(forResource: "catalog", withExtension: "json") {
            await load(from: sample, source: .sample, persist: false)
        }
    }

    func importCatalog(from url: URL) async {
        await load(from: url, source: .imported(url), persist: true)
    }

    func resetToSample() async {
        try? FileManager.default.removeItem(at: Self.importedCatalogURL)
        selection = nil
        await loadInitialCatalog()
    }

    /// Parses off the main thread, then publishes the results.
    private func load(from url: URL, source: Source, persist: Bool) async {
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
            selection = nil
            refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func refresh() {
        result = engine.search(query, options: .init(showUntested: showUntested))
        if let selection, !result.entries.contains(where: { $0.id == selection }) {
            self.selection = nil
        }
    }
}
