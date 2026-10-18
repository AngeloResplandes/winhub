import Foundation
import Testing
import WinHubCore
@testable import WinHubRuntime

@Suite struct RecipeAvailabilityTests {
    @Test func comparesMinAppVersion() throws {
        let json = #"{"bottleName": "B", "minAppVersion": "0.2.60", "installer": {"url": "https://example.invalid/a.exe"}, "launch": {"windowsPath": "C:\\a.exe"}}"#
        let recipe = try JSONDecoder().decode(Recipe.self, from: Data(json.utf8))
        #expect(!recipe.isSupported(by: try #require(AppVersion("0.2.59"))))
        #expect(recipe.isSupported(by: try #require(AppVersion("0.2.60"))))
        #expect(recipe.isSupported(by: try #require(AppVersion("0.2.61"))))
        let none = try JSONDecoder().decode(
            Recipe.self,
            from: Data(#"{"bottleName": "B", "installer": {"url": "https://example.invalid/a.exe"}, "launch": {"windowsPath": "C:\\a.exe"}}"#.utf8))
        #expect(none.isSupported(by: try #require(AppVersion("0.1"))))
        #expect(AppVersion("0.2") == AppVersion("0.2.0"))
    }

    @Test func appliesSettingsOnANewBottle() throws {
        let json = #"""
        {"bottleName": "B", "installer": {"url": "https://example.invalid/a.exe"}, "launch": {"windowsPath": "C:\\a.exe"},
         "settings": {"graphics": "dxmt", "msync": true, "environment": {"FOO": "bar"}, "dllOverrides": {"d3d11": "n,b"}}}
        """#
        let recipe = try JSONDecoder().decode(Recipe.self, from: Data(json.utf8))
        var bottle = Bottle(name: "B", runtimeID: "w")
        #expect(bottle.graphics == .wined3d)
        #expect(!bottle.msync)
        recipe.applySettingsIfCreating(&bottle)
        #expect(bottle.graphics == .dxmt)
        #expect(bottle.msync)
        #expect(bottle.environment == ["FOO": "bar"])
        #expect(bottle.dllOverrides == ["d3d11": "n,b"])
    }

    @Test func ignoresUnknownGraphicsInSettings() throws {
        let json = #"""
        {"bottleName": "B", "installer": {"url": "https://example.invalid/a.exe"}, "launch": {"windowsPath": "C:\\a.exe"},
         "settings": {"graphics": "nope"}}
        """#
        let recipe = try JSONDecoder().decode(Recipe.self, from: Data(json.utf8))
        var bottle = Bottle(name: "B", runtimeID: "w")
        recipe.applySettingsIfCreating(&bottle)
        #expect(bottle.graphics == .wined3d)
    }

    @Test func upsertKeepsProgramRulesAndReplacesSameDesc() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        var bottle = Bottle(name: "T", runtimeID: "w")
        bottle.folder = dir
        try CompatRules.setProgramBackend(.dxmt, program: #"C:\a.exe"#, in: bottle)

        let first = Recipe.Rule(
            desc: "gog",
            match: .init(type: "path_suffix", suffix: "GalaxyClient.exe"),
            hacks: [.init(type: "graphics_backend", backend: "dxmt", force: true)])
        try CompatRules.upsert(try CompatRules.dictionary(from: first), in: bottle)
        let afterFirst = CompatRules.rules(in: bottle)
        #expect(afterFirst.contains { ($0["desc"] as? String) == CompatRules.programPrefix + #"C:\a.exe"# })
        #expect(afterFirst.contains { ($0["desc"] as? String) == "gog" })

        let second = Recipe.Rule(
            desc: "gog",
            match: .init(type: "path_suffix", suffix: "GalaxyClient.exe"),
            hacks: [.init(type: "graphics_backend", backend: "dxvk", force: true)])
        try CompatRules.upsert(try CompatRules.dictionary(from: second), in: bottle)
        let list = CompatRules.rules(in: bottle)
        #expect(list.filter { ($0["desc"] as? String) == "gog" }.count == 1)
        #expect(list.contains { ($0["desc"] as? String) == CompatRules.programPrefix + #"C:\a.exe"# })
        let gog = try #require(list.first { ($0["desc"] as? String) == "gog" })
        let hacks = try #require(gog["hacks"] as? [[String: Any]])
        #expect(hacks.first?["backend"] as? String == "dxvk")
    }
}
