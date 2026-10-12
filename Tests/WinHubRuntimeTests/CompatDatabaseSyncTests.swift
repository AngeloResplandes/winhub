import CryptoKit
import Foundation
import Testing
@testable import WinHubRuntime

@Suite struct CompatDatabaseSyncTests {
    let key = Curve25519.Signing.PrivateKey()

    func database(_ timestamp: Int) -> Data {
        Data(#"{"version": 1, "timestamp": \#(timestamp), "rules": []}"#.utf8)
    }

    func sign(_ data: Data, with key: Curve25519.Signing.PrivateKey? = nil) throws -> Data {
        Data((try (key ?? self.key).signature(for: data).base64EncodedString() + "\n").utf8)
    }

    func sync(in dir: URL) -> CompatDatabaseSync {
        CompatDatabaseSync(baseURL: dir.appending(path: "published", directoryHint: .isDirectory),
                           directory: dir.appending(path: "home/compat", directoryHint: .isDirectory),
                           publicKey: key.publicKey.rawRepresentation.base64EncodedString())
    }

    @Test func checksSignatureFormatAndAge() throws {
        let sync = sync(in: URL(fileURLWithPath: "/unused"))
        let data = database(200)
        #expect(try sync.check(data, signature: try sign(data), installed: nil) == 200)
        #expect(try sync.check(data, signature: try sign(data), installed: database(100)) == 200)

        var tampered = data
        tampered[tampered.count - 3] = UInt8(ascii: " ")
        #expect(throws: CompatDatabaseSync.Failure.badSignature) {
            try sync.check(tampered, signature: try sign(data), installed: nil)
        }
        #expect(throws: CompatDatabaseSync.Failure.badSignature) {
            try sync.check(data, signature: try sign(data, with: Curve25519.Signing.PrivateKey()), installed: nil)
        }
        #expect(throws: CompatDatabaseSync.Failure.badSignature) {
            try sync.check(data, signature: Data("not base64".utf8), installed: nil)
        }
        #expect(throws: CompatDatabaseSync.Failure.notNewer(installed: 300, downloaded: 200)) {
            try sync.check(data, signature: try sign(data), installed: database(300))
        }
        let wrongVersion = Data(#"{"version": 2, "timestamp": 1, "rules": []}"#.utf8)
        #expect(throws: CompatDatabaseSync.Failure.invalid) {
            try sync.check(wrongVersion, signature: try sign(wrongVersion), installed: nil)
        }
    }

    @Test func installsOnlyNewerSignedDatabases() async throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let sync = sync(in: dir)
        let published = sync.baseURL
        try FileManager.default.createDirectory(at: published, withIntermediateDirectories: true)
        func publish(_ data: Data, signature: Data) throws {
            try data.write(to: published.appending(path: "compatdb.json"))
            try signature.write(to: published.appending(path: "compatdb.json.sig"))
        }

        try publish(database(200), signature: try sign(database(200)))
        #expect(await sync.sync())
        #expect(try Data(contentsOf: sync.localURL) == database(200))
        #expect(!(await sync.sync()))                     // nothing new

        try publish(database(100), signature: try sign(database(100)))
        #expect(!(await sync.sync()))                     // older: kept the installed one
        try publish(database(300), signature: try sign(database(200)))
        #expect(!(await sync.sync()))                     // signature for other bytes
        #expect(try Data(contentsOf: sync.localURL) == database(200))

        try publish(database(300), signature: try sign(database(300)))
        #expect(await sync.sync())
        #expect(try Data(contentsOf: sync.localURL) == database(300))
    }

    @Test func builtInKeyIsAValidEd25519Key() throws {
        let raw = try #require(Data(base64Encoded: CompatDatabaseSync.publicKey))
        _ = try Curve25519.Signing.PublicKey(rawRepresentation: raw)
    }
}
