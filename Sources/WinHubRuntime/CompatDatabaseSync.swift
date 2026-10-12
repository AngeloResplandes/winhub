import CryptoKit
import Foundation

/// The compatibility database published in winhub-engine (`data/compatdb.json`), downloaded for the
/// engine's winhubcompat, which reads `WINHUB_HOME/compat/compatdb.json` without checking it. Only a
/// file signed with the project's key (Ed25519 over the exact bytes, in `compatdb.json.sig`) and not
/// older than the one already here is installed.
public struct CompatDatabaseSync: Sendable {
    /// Public half of the key that signs the database (winhub-engine's `data/compatdb-public-key.txt`).
    public static let publicKey = "9m8wizsdHO8pdSxJi19cO8mUbnpjr0IfbSpNjkTfJuE="
    public static let defaultBaseURL = URL(string: "https://raw.githubusercontent.com/AngeloResplandes/winhub-engine/main/data/")!
    public static let fileName = "compatdb.json"

    public enum Failure: Error, Equatable {
        case badSignature
        case invalid
        /// Same or older `timestamp` than the installed database.
        case notNewer(installed: Double, downloaded: Double)
    }

    public let baseURL: URL
    public let directory: URL
    public let publicKey: String

    public init(baseURL: URL = Self.defaultBaseURL,
                directory: URL = WineEnvironment.winhubHome.appending(path: "compat", directoryHint: .isDirectory),
                publicKey: String = Self.publicKey) {
        self.baseURL = baseURL
        self.directory = directory
        self.publicKey = publicKey
    }

    public var localURL: URL { directory.appending(path: Self.fileName) }

    /// Checks a downloaded database and returns its timestamp. `installed` is the current file, if any.
    public func check(_ data: Data, signature: Data, installed: Data?) throws -> Double {
        guard let keyData = Data(base64Encoded: publicKey),
              let key = try? Curve25519.Signing.PublicKey(rawRepresentation: keyData),
              let text = String(data: signature, encoding: .utf8),
              let signatureData = Data(base64Encoded: text.trimmingCharacters(in: .whitespacesAndNewlines)),
              key.isValidSignature(signatureData, for: data) else { throw Failure.badSignature }
        guard let timestamp = Self.timestamp(of: data) else { throw Failure.invalid }
        if let installed, let current = Self.timestamp(of: installed), timestamp <= current {
            throw Failure.notNewer(installed: current, downloaded: timestamp)
        }
        return timestamp
    }

    /// `timestamp` of a database in the format winhubcompat reads (version 1).
    static func timestamp(of data: Data) -> Double? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              root["version"] as? Int == 1, root["rules"] is [Any],
              let timestamp = root["timestamp"] as? NSNumber else { return nil }
        return timestamp.doubleValue
    }

    /// Downloads, checks and installs the database. Returns `true` when a newer one was installed;
    /// a failed download or check keeps the current file.
    @discardableResult
    public func sync() async -> Bool {
        guard let data = await download(Self.fileName),
              let signature = await download(Self.fileName + ".sig") else { return false }
        let installed = try? Data(contentsOf: localURL)
        guard installed != data, (try? check(data, signature: signature, installed: installed)) != nil else { return false }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: localURL, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    private func download(_ name: String) async -> Data? {
        var request = URLRequest(url: baseURL.appending(path: name))
        request.cachePolicy = .reloadIgnoringLocalCacheData
        guard let (data, response) = try? await URLSession.shared.data(for: request) else { return nil }
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) { return nil }
        return data
    }
}
