import Foundation
import Testing
@testable import WinHubCore

@Suite struct RecipeExpandedTests {
    private func decode(_ json: String) throws -> Recipe {
        try JSONDecoder().decode(Recipe.self, from: Data(json.utf8))
    }

    @Test func decodesExpandedRecipe() throws {
        let json = #"""
        {
          "bottleName": "Exemplo",
          "windowsVersion": "win10",
          "dependencies": ["vcrun2022"],
          "minAppVersion": "0.2.60",
          "installer": {
            "url": "https://vendor.example/app.zip",
            "sha256": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            "kind": "zip",
            "extractTo": "Program Files\\App",
            "arguments": []
          },
          "settings": {
            "graphics": "dxmt",
            "msync": true,
            "environment": { "FOO": "bar" },
            "dllOverrides": { "d3d11": "n,b" }
          },
          "rules": [
            {
              "desc": "exemplo-cliente",
              "match": { "type": "path_suffix", "suffix": "App.exe" },
              "hacks": [{ "type": "graphics_backend", "backend": "dxmt", "force": true }]
            }
          ],
          "steps": [
            { "kind": "run", "windowsPath": "C:\\Program Files\\App\\setup.exe", "arguments": ["/S"] },
            { "kind": "registry", "key": "HKCU\\Software\\App", "value": "Installed", "data": "1" },
            { "kind": "copy", "from": "C:\\Program Files\\App\\extra.dll", "to": "C:\\windows\\system32\\extra.dll" }
          ],
          "launch": { "windowsPath": "C:\\Program Files\\App\\App.exe" },
          "launches": [
            { "name": "Configuração", "windowsPath": "C:\\Program Files\\App\\config.exe" }
          ]
        }
        """#
        let recipe = try decode(json)
        #expect(recipe.bottleName == "Exemplo")
        #expect(recipe.minAppVersion == "0.2.60")
        #expect(recipe.installer.kind == .zip)
        #expect(recipe.installer.resolvedKind == .zip)
        #expect(recipe.installer.extractTo == #"Program Files\App"#)
        #expect(recipe.settings?.graphics == "dxmt")
        #expect(recipe.settings?.msync == true)
        #expect(recipe.settings?.environment == ["FOO": "bar"])
        #expect(recipe.settings?.dllOverrides == ["d3d11": "n,b"])
        #expect(recipe.rules.count == 1)
        #expect(recipe.rules[0].desc == "exemplo-cliente")
        #expect(recipe.rules[0].match.type == "path_suffix")
        #expect(recipe.rules[0].match.suffix == "App.exe")
        #expect(recipe.rules[0].hacks[0].type == "graphics_backend")
        #expect(recipe.rules[0].hacks[0].backend == "dxmt")
        #expect(recipe.rules[0].hacks[0].force == true)
        #expect(recipe.steps.count == 3)
        guard case .run(let windowsPath, let arguments) = recipe.steps[0] else {
            Issue.record("expected run step"); return
        }
        #expect(windowsPath == #"C:\Program Files\App\setup.exe"#)
        #expect(arguments == ["/S"])
        guard case .registry(let key, let value, let data, let type) = recipe.steps[1] else {
            Issue.record("expected registry step"); return
        }
        #expect(key == #"HKCU\Software\App"#)
        #expect(value == "Installed")
        #expect(data == "1")
        #expect(type == "REG_SZ")
        guard case .copy(let from, let to) = recipe.steps[2] else {
            Issue.record("expected copy step"); return
        }
        #expect(from == #"C:\Program Files\App\extra.dll"#)
        #expect(to == #"C:\windows\system32\extra.dll"#)
        #expect(recipe.launch.windowsPath == #"C:\Program Files\App\App.exe"#)
        #expect(recipe.additionalLaunches.count == 1)
        #expect(recipe.additionalLaunches[0].name == "Configuração")
        #expect(recipe.allLaunches.count == 2)
    }

    @Test func usesFirstLaunchWhenOnlyLaunchesArePresent() throws {
        let json = #"""
        {"bottleName": "B", "installer": {"url": "https://example.invalid/a.exe"},
         "launches": [
           {"windowsPath": "C:\\a.exe"},
           {"name": "Cfg", "windowsPath": "C:\\b.exe"}
         ]}
        """#
        let recipe = try decode(json)
        #expect(recipe.launch.windowsPath == #"C:\a.exe"#)
        #expect(recipe.additionalLaunches.count == 1)
        #expect(recipe.additionalLaunches[0].name == "Cfg")
        #expect(recipe.allLaunches.count == 2)
    }

    @Test func rejectsRecipeWithNoLaunch() {
        let json = #"{"bottleName": "B", "installer": {"url": "https://example.invalid/a.exe"}}"#
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(Recipe.self, from: Data(json.utf8))
        }
    }

    @Test func infersZipKindFromURL() throws {
        let json = #"""
        {"bottleName": "B",
         "installer": {"url": "https://example.invalid/app.zip", "extractTo": "Program Files\\App"},
         "launch": {"windowsPath": "C:\\Program Files\\App\\a.exe"}}
        """#
        let recipe = try decode(json)
        #expect(recipe.installer.kind == nil)
        #expect(recipe.installer.resolvedKind == .zip)
        #expect(recipe.installer.extractTo == #"Program Files\App"#)
    }

    @Test func rejectsZipWithoutExtractTo() {
        let json = #"""
        {"bottleName": "B",
         "installer": {"url": "https://example.invalid/app.zip"},
         "launch": {"windowsPath": "C:\\a.exe"}}
        """#
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(Recipe.self, from: Data(json.utf8))
        }
    }

    @Test func infersMsiKindFromURL() throws {
        let json = #"""
        {"bottleName": "B",
         "installer": {"url": "https://example.invalid/app.msi"},
         "launch": {"windowsPath": "C:\\a.exe"}}
        """#
        let recipe = try decode(json)
        #expect(recipe.installer.resolvedKind == .msi)
    }

    @Test func launchTitleUsesNameOrFileName() {
        #expect(Recipe.Launch(windowsPath: #"C:\Program Files\App\config.exe"#, name: "Configuração").title
                == "Configuração")
        #expect(Recipe.Launch(windowsPath: #"C:\Program Files\App\App.exe"#).title == "App.exe")
    }
}
