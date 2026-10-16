import Foundation
import Testing
@testable import WinHubCore

@Suite struct LikePatternTests {
    @Test func emptyQueryHasNoPattern() {
        #expect(CatalogSearchEngine.likePattern(for: "") == nil)
        #expect(CatalogSearchEngine.likePattern(for: "  \n\t ") == nil)
    }

    @Test func wordsBecomeOrderedWildcards() {
        #expect(CatalogSearchEngine.likePattern(for: "  half   life ") == "*half*life*")
    }

    @Test func wildcardCharactersAreEscaped() {
        #expect(CatalogSearchEngine.likePattern(for: "a*b?") == "*a\\*b\\?*")
        #expect(CatalogSearchEngine.likePattern(for: "c\\d") == "*c\\\\d*")
    }
}

@Suite struct WildcardPatternTests {
    @Test func matchesWordsInOrderAnywhereInName() {
        let pattern = WildcardPattern("*half*life*")
        #expect(pattern.matches("Half-Life 2"))
        #expect(pattern.matches("Black Mesa: Half-Life Remake"))
        #expect(!pattern.matches("Life is Half"))
    }

    @Test func ignoresCaseAndDiacritics() {
        #expect(WildcardPattern("*pokemon*").matches("Pokémon Trading Card Game"))
        #expect(WildcardPattern("*ÉLITE*").matches("Elite Dangerous"))
    }

    @Test func escapedWildcardsAreLiteral() {
        #expect(WildcardPattern("*a\\*b*").matches("xa*by"))
        #expect(!WildcardPattern("*a\\*b*").matches("xaZZby"))
        #expect(WildcardPattern("*q\\?*").matches("why q?"))
        #expect(!WildcardPattern("*q\\?*").matches("qz"))
    }

    @Test func questionMarkMatchesOneCharacter() {
        #expect(WildcardPattern("a?c").matches("abc"))
        #expect(!WildcardPattern("a?c").matches("ac"))
    }

    @Test func isAnchored() {
        #expect(!WildcardPattern("half").matches("half life"))
        #expect(WildcardPattern("half*").matches("half life"))
    }

    /// The matcher must agree with Foundation's `LIKE[cd]` on the same patterns.
    @Test(arguments: ["*half*life*", "*excel*", "a?c", "*a\\*b*", "*É*", "half*"])
    func agreesWithNSPredicate(pattern: String) {
        let names = ["Half-Life 2", "Life is Half", "Excel 2000", "Excellent", "abc", "ac", "xa*by",
                     "Élite", "elite", "half life", "Pokémon"]
        let predicate = NSPredicate(format: "SELF LIKE[cd] %@", pattern)
        for name in names {
            #expect(WildcardPattern(pattern).matches(name) == predicate.evaluate(with: name), "\(pattern) vs \(name)")
        }
    }
}

@Suite struct CatalogSearchEngineTests {
    let catalog: [CatalogEntry] = [
        CatalogEntry(id: "1", name: "Half-Life 2", rating: .excellent, isFeatured: true),
        CatalogEntry(id: "2", name: "Half-Life", rating: .good),
        CatalogEntry(id: "3", name: "Halo Wars", rating: .untested),
        CatalogEntry(id: "4", name: "Hades", rating: .doesNotInstall, isFeatured: true),
        CatalogEntry(id: "5", name: "Game 10", rating: .good),
        CatalogEntry(id: "6", name: "Game 9", rating: .good),
        CatalogEntry(id: "7", name: "", rating: .excellent),
        CatalogEntry(id: "8", name: "Microsoft Excel 2000", localizedNames: ["pt": "Excel 2000"], rating: .limited),
    ]

    @Test func emptyQueryShowsTestedFeaturedTitles() {
        let result = CatalogSearchEngine(entries: catalog).search("", options: .init(showUntested: false))
        #expect(result.isFeatured)
        #expect(result.entries.map(\.id) == ["1"])
    }

    @Test func emptyQueryWithUntestedShowsAllFeatured() {
        let result = CatalogSearchEngine(entries: catalog).search("", options: .init(showUntested: true))
        #expect(result.entries.map(\.id) == ["4", "1"])
    }

    @Test func showsUntestedByDefault() {
        #expect(CatalogSearchEngine.Options().showUntested)
    }

    @Test func queryCanHideUntested() {
        let engine = CatalogSearchEngine(entries: catalog)
        #expect(engine.search("ha", options: .init(showUntested: false)).entries.map(\.name) == ["Half-Life", "Half-Life 2"])
        #expect(engine.search("ha", options: .init(showUntested: true)).entries.map(\.name)
                == ["Hades", "Half-Life", "Half-Life 2", "Halo Wars"])
    }

    @Test func sortsInNaturalOrder() {
        let result = CatalogSearchEngine(entries: catalog).search("game")
        #expect(result.entries.map(\.name) == ["Game 9", "Game 10"])
    }

    @Test func searchesTheLocalizedName() {
        let engine = CatalogSearchEngine(entries: catalog, preferredLanguages: ["pt-BR"])
        #expect(engine.search("excel").entries.map(\.id) == ["8"])
        #expect(engine.search("microsoft").entries.isEmpty)
        #expect(CatalogSearchEngine(entries: catalog, preferredLanguages: ["en"]).search("microsoft").entries.map(\.id) == ["8"])
    }

    @Test func entriesWithoutNameAreNotListed() {
        #expect(CatalogSearchEngine(entries: catalog).entries.count == 7)
    }

    @Test func capsResultsAt128() {
        let many = (0..<300).map { CatalogEntry(id: "\($0)", name: "Title \($0)", rating: .good) }
        let result = CatalogSearchEngine(entries: many).search("title")
        #expect(result.entries.count == 128)
        #expect(result.totalMatches == 300)
        #expect(result.isTruncated)
    }

    @Test func noResultsState() {
        #expect(CatalogSearchEngine(entries: catalog).search("zzz").showsNoResults)
        #expect(!CatalogSearchEngine(entries: []).search("zzz").showsNoResults)
    }
}

@Suite struct CatalogEntryTests {
    @Test func displayNameIgnoresLanguageKeyCase() {
        let entry = CatalogEntry(id: "x", name: "Default", localizedNames: ["pt-br": "Brasil", "pt": "Portugal"])
        #expect(entry.displayName(preferredLanguages: ["pt-BR"]) == "Brasil")
        #expect(entry.displayName(preferredLanguages: ["pt-PT"]) == "Portugal")
        #expect(entry.displayName(preferredLanguages: ["fr"]) == "Default")
    }

    @Test func displaySummaryFollowsLanguage() {
        let entry = CatalogEntry(id: "x", name: "X", summary: "Resumo", localizedSummaries: ["en": "Summary"])
        #expect(entry.displaySummary(preferredLanguages: ["en-US", "pt-BR"]) == "Summary")
        #expect(entry.displaySummary(preferredLanguages: ["pt-BR", "en"]) == "Resumo")
        #expect(entry.displaySummary(preferredLanguages: ["fr"]) == "Resumo")
    }

    /// Regional Spanish (Spain, Latin America) falls back to the catalog's plain "es".
    @Test func displaySummaryFallsBackToBaseSpanish() {
        let entry = CatalogEntry(id: "x", name: "X", summary: "Resumo", localizedSummaries: ["en": "Summary", "es": "Resumen"])
        #expect(entry.displaySummary(preferredLanguages: ["es-419"]) == "Resumen")
        #expect(entry.displaySummary(preferredLanguages: ["es-ES", "en"]) == "Resumen")
        #expect(entry.displaySummary(preferredLanguages: ["es_MX"]) == "Resumen")
    }

    @Test func decodesMinimalJSON() throws {
        let json = #"[{"id": "a", "name": "App"}]"#
        let entries = try JSONDecoder().decode([CatalogEntry].self, from: Data(json.utf8))
        #expect(entries[0].localizedSummaries.isEmpty)
        #expect(entries[0].rating == .untested)
        #expect(!entries[0].isFeatured)
        #expect(entries[0].steamID == nil)
        #expect(entries[0].steamGame == nil)
    }

    @Test func decodesSteamGame() throws {
        let json = #"[{"id": "a", "name": "G", "steamID": 1, "steamGame": {"installDir": "My Game", "executable": "bin/game.exe", "graphics": "dxmt"}}, {"id": "b", "name": "Bad", "steamGame": {"installDir": 3}}]"#
        let entries = try JSONDecoder().decode([CatalogEntry].self, from: Data(json.utf8))
        let game = try #require(entries[0].steamGame)
        #expect(game.graphics == "dxmt")
        #expect(game.windowsPath == #"C:\Program Files (x86)\Steam\steamapps\common\My Game\bin\game.exe"#)
        // A malformed block is ignored instead of hiding the title.
        #expect(entries[1].steamGame == nil)
    }
}

@Suite struct RatingTests {
    @Test func labels() {
        #expect(Rating.allCases.map(\.title) == [
            "Fonte não confiável", "Sem teste", "Não instala", "Instala, mas não abre",
            "Funciona com limitações", "Bom", "Excelente",
        ])
    }

    @Test func testedRatings() {
        #expect(!Rating.untested.isTested)
        #expect(!Rating.doesNotInstall.isTested)
        #expect(Rating.installsButDoesNotRun.isTested)
        #expect(Rating(clamping: 9) == .excellent)
        #expect(Rating(clamping: -3) == .unverified)
    }
}

@Suite struct RecipeTests {
    @Test func decodesRecipeWithDefaults() throws {
        let json = #"""
        {"id": "s", "name": "Steam", "recipe": {"bottleName": "Steam",
          "installer": {"url": "https://cdn.cloudflare.steamstatic.com/client/installer/SteamSetup.exe", "arguments": ["/S"]},
          "launch": {"windowsPath": "C:\\Program Files (x86)\\Steam\\steam.exe"}}}
        """#
        let entry = try JSONDecoder().decode(CatalogEntry.self, from: Data(json.utf8))
        let recipe = try #require(entry.recipe)
        #expect(recipe.windowsVersion == "win10")
        #expect(recipe.installer.sha256 == nil)
        #expect(recipe.installer.fileName == "SteamSetup.exe")
        #expect(recipe.launch.windowsPath == #"C:\Program Files (x86)\Steam\steam.exe"#)
        #expect(recipe.launch.arguments.isEmpty)
    }

    @Test func sampleCatalogHasSteamRecipe() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "Sources/WinHub/Resources/catalog.json")
        let entries = try JSONCatalog.load(from: url)
        let steam = try #require(entries.first { $0.name == "Steam" })
        #expect(steam.recipe?.bottleName == SteamClient.bottleName)
        #expect(steam.recipe?.launch.windowsPath == SteamClient.windowsPath)
        #expect(steam.recipe?.installer.url.host() == "cdn.cloudflare.steamstatic.com")
    }

    @Test func sampleCatalogRecommendsDXMTForHollowKnight() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "Sources/WinHub/Resources/catalog.json")
        let knight = try #require(try JSONCatalog.load(from: url).first { $0.steamID == 367520 })
        #expect(knight.steamGame?.executable == "hollow_knight.exe")
        #expect(knight.steamGame?.graphics == "dxmt")
        #expect(knight.rating == .good)
    }

    @Test func renamedSteamBottle() {
        #expect(SteamClient.isRenamedClientBottle(original: "Steam", imported: "Steam (2)"))
        #expect(SteamClient.isRenamedClientBottle(original: "steam", imported: "steam (2)"))
        #expect(!SteamClient.isRenamedClientBottle(original: "Steam", imported: "Steam"))
        #expect(!SteamClient.isRenamedClientBottle(original: "Jogos", imported: "Jogos (2)"))
    }

    @Test func steamRunArguments() {
        #expect(SteamClient.runArguments(appID: 220, wrapperInstalled: true) == ["-noverifyfiles", "steam://run/220"])
        #expect(SteamClient.runArguments(appID: 220, wrapperInstalled: false) == ["steam://run/220"])
    }

    @Test func steamClientSkipsFileVerificationOnlyWithWrapper() {
        #expect(SteamClient.arguments(forOpening: SteamClient.windowsPath, wrapperInstalled: true) == ["-noverifyfiles"])
        #expect(SteamClient.arguments(forOpening: "c:/program files (x86)/steam/STEAM.EXE", ["-silent"],
                                      wrapperInstalled: true) == ["-noverifyfiles", "-silent"])
        #expect(SteamClient.arguments(forOpening: SteamClient.windowsPath, ["-noverifyfiles"],
                                      wrapperInstalled: true) == ["-noverifyfiles"])
        #expect(SteamClient.arguments(forOpening: #"C:\Games\game.exe"#, ["-x"], wrapperInstalled: true) == ["-x"])
    }

    /// The first start after installing must not skip the check: Steam then never
    /// downloads its client.
    @Test func firstStartChecksFiles() {
        #expect(SteamClient.arguments(forOpening: SteamClient.windowsPath, wrapperInstalled: false) == [])
        #expect(SteamClient.arguments(forOpening: SteamClient.windowsPath, ["-silent"], wrapperInstalled: false)
                == ["-silent"])
    }

    @Test func recognizesSteamClientShortcut() {
        #expect(SteamClient.isClientShortcut(named: "Steam"))
        #expect(SteamClient.isClientShortcut(named: "steam"))
        #expect(!SteamClient.isClientShortcut(named: "Steam Support Center"))
    }
}

@Suite struct RecipeDependencyTests {
    @Test func decodesDependencies() throws {
        let json = #"{"bottleName": "B", "dependencies": ["vcrun2022", "corefonts"], "installer": {"url": "https://example.invalid/a.exe"}, "launch": {"windowsPath": "C:\\a.exe"}}"#
        let recipe = try JSONDecoder().decode(Recipe.self, from: Data(json.utf8))
        #expect(recipe.dependencies == ["vcrun2022", "corefonts"])
    }
}
