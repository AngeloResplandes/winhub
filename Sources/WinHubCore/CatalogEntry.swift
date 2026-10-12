import Foundation

/// One searchable title in the WinHub catalog.
public struct CatalogEntry: Identifiable, Hashable, Codable, Sendable {
    public var id: String
    /// Default name; `localizedNames` can override it per language.
    public var name: String
    public var localizedNames: [String: String]
    /// Slash-separated path such as "Games/Action Games".
    public var category: String
    /// Default summary (Brazilian Portuguese); `localizedSummaries` can override it per language.
    public var summary: String
    public var localizedSummaries: [String: String]
    public var rating: Rating
    /// Shown in the "Destaques" list when the search field is empty.
    public var isFeatured: Bool
    public var steamID: Int?
    /// Where Steam puts the game and the Direct3D that worked best for it in WinHub's tests.
    public var steamGame: SteamGame?
    /// How to install and open the title, when WinHub knows it.
    public var recipe: Recipe?

    public init(
        id: String,
        name: String,
        localizedNames: [String: String] = [:],
        category: String = "",
        summary: String = "",
        localizedSummaries: [String: String] = [:],
        rating: Rating = .untested,
        isFeatured: Bool = false,
        steamID: Int? = nil,
        steamGame: SteamGame? = nil,
        recipe: Recipe? = nil
    ) {
        self.id = id
        self.name = name
        self.localizedNames = localizedNames
        self.category = category
        self.summary = summary
        self.localizedSummaries = localizedSummaries
        self.rating = rating
        self.isFeatured = isFeatured
        self.steamID = steamID
        self.steamGame = steamGame
        self.recipe = recipe
    }

    enum CodingKeys: String, CodingKey {
        case id, name, localizedNames, category, summary, localizedSummaries, rating, isFeatured, steamID, steamGame, recipe
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        localizedNames = try c.decodeIfPresent([String: String].self, forKey: .localizedNames) ?? [:]
        category = try c.decodeIfPresent(String.self, forKey: .category) ?? ""
        summary = try c.decodeIfPresent(String.self, forKey: .summary) ?? ""
        localizedSummaries = try c.decodeIfPresent([String: String].self, forKey: .localizedSummaries) ?? [:]
        rating = try c.decodeIfPresent(Rating.self, forKey: .rating) ?? .untested
        isFeatured = try c.decodeIfPresent(Bool.self, forKey: .isFeatured) ?? false
        steamID = try c.decodeIfPresent(Int.self, forKey: .steamID)
        steamGame = try? c.decodeIfPresent(SteamGame.self, forKey: .steamGame)
        recipe = try c.decodeIfPresent(Recipe.self, forKey: .recipe)
    }

    /// A Steam game as installed in the Steam client's bottle.
    public struct SteamGame: Codable, Sendable, Hashable {
        /// Folder under `steamapps\common`.
        public var installDir: String
        /// The game's `.exe`, relative to `installDir`.
        public var executable: String
        /// Recommended Direct3D for this game alone (`"dxmt"`, `"dxvk"`), when tested.
        public var graphics: String?

        public init(installDir: String, executable: String, graphics: String? = nil) {
            self.installDir = installDir
            self.executable = executable
            self.graphics = graphics
        }

        /// Windows path of the executable in the Steam client's default library.
        public var windowsPath: String {
            #"C:\Program Files (x86)\Steam\steamapps\common\"# + installDir + #"\"#
                + executable.replacingOccurrences(of: "/", with: #"\"#)
        }
    }

    public var categoryPath: [String] { category.split(separator: "/").map(String.init) }

    /// Name in the user's preferred language, falling back to `name`.
    public func displayName(preferredLanguages: [String] = Locale.preferredLanguages) -> String {
        Self.localized(localizedNames, default: name, preferredLanguages: preferredLanguages)
    }

    /// Summary in the user's preferred language, falling back to `summary` (Brazilian Portuguese, which also
    /// wins when it comes first in the user's list).
    public func displaySummary(preferredLanguages: [String] = Locale.preferredLanguages) -> String {
        Self.localized(localizedSummaries.merging(["pt": summary]) { own, _ in own }, default: summary,
                       preferredLanguages: preferredLanguages)
    }

    /// Language keys are matched without regard to case ("pt-br" == "pt-BR"), first the full code, then the
    /// base language, in the order of the user's preferences.
    static func localized(_ values: [String: String], default value: String, preferredLanguages: [String]) -> String {
        for language in preferredLanguages {
            let full = language.lowercased().replacingOccurrences(of: "_", with: "-")
            let base = String(full.split(separator: "-").first ?? Substring(full))
            for key in [full, base] {
                if let localized = values.first(where: { $0.key.lowercased() == key })?.value, !localized.isEmpty {
                    return localized
                }
            }
        }
        return value
    }
}
