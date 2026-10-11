import Foundation

/// Keeps local copies of the data files published in the repository (catalog and manifests),
/// so they update with every commit instead of only with a new app.
public struct RemoteDataSync: Sendable {
    public struct File: Sendable {
        public var name: String
        /// Throws if the data cannot be used by this version of the app.
        public var validate: @Sendable (Data) throws -> Void

        public init(name: String, validate: @escaping @Sendable (Data) throws -> Void) {
            self.name = name
            self.validate = validate
        }
    }

    public let baseURL: URL
    public let directory: URL

    public init(baseURL: URL, directory: URL = RemoteDataSync.defaultDirectory) {
        self.baseURL = baseURL
        self.directory = directory
    }

    public static var defaultDirectory: URL {
        URL.applicationSupportDirectory.appending(path: "WinHub/Remote", directoryHint: .isDirectory)
    }

    /// Where the app's bundled data lives in the repository.
    public static func baseURL(repository: String, branch: String = "main") -> URL {
        URL(string: "https://raw.githubusercontent.com/\(repository)/\(branch)/Sources/WinHub/Resources/")!
    }

    public func localURL(for name: String) -> URL {
        directory.appending(path: name)
    }

    /// Downloads every file; keeps the previous copy when a download fails or does not validate.
    /// Returns the names whose content changed.
    public func sync(_ files: [File]) async -> Set<String> {
        var changed: Set<String> = []
        for file in files {
            var request = URLRequest(url: baseURL.appending(path: file.name))
            request.cachePolicy = .reloadIgnoringLocalCacheData
            guard let (data, response) = try? await URLSession.shared.data(for: request) else { continue }
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) { continue }
            let destination = localURL(for: file.name)
            guard (try? Data(contentsOf: destination)) != data, (try? file.validate(data)) != nil else { continue }
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                try data.write(to: destination, options: .atomic)
                changed.insert(file.name)
            } catch {
                continue
            }
        }
        return changed
    }
}
