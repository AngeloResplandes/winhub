import Foundation

public enum CatalogLoaderError: Error, LocalizedError {
    case unreadable(URL, Error)

    public var errorDescription: String? {
        switch self {
        case .unreadable(let url, let error): "Não foi possível ler \(url.lastPathComponent): \(error.localizedDescription)"
        }
    }
}

/// WinHub's own catalog format: a JSON array of `CatalogEntry`.
public enum JSONCatalog {
    public static func load(from url: URL) throws -> [CatalogEntry] {
        do {
            return try JSONDecoder().decode([CatalogEntry].self, from: Data(contentsOf: url))
        } catch {
            throw CatalogLoaderError.unreadable(url, error)
        }
    }

    public static func save(_ entries: [CatalogEntry], to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(entries).write(to: url, options: .atomic)
    }
}
