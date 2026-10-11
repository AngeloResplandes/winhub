import Foundation

/// One searchable title in the WinHub catalog.
public struct CatalogEntry: Identifiable, Hashable, Codable, Sendable {
    public var id: String
    /// Default name; `localizedNames` can override it per language.
    public var name: String
    public var localizedNames: [String: String]
    /// Slash-separated path such as "Games/Action Games".
    public var category: String
    public var summary: String
    public var rating: Rating
    /// Shown in the "Destaques" list when the search field is empty.
    public var isFeatured: Bool
    public var steamID: Int?
    /// How to install and open the title, when WinHub knows it.
    public var recipe: Recipe?

    public init(
        id: String,
        name: String,
        localizedNames: [String: String] = [:],
        category: String = "",
        summary: String = "",
        rating: Rating = .untested,
        isFeatured: Bool = false,
        steamID: Int? = nil,
        recipe: Recipe? = nil
    ) {
        self.id = id
        self.name = name
        self.localizedNames = localizedNames
        self.category = category
        self.summary = summary
        self.rating = rating
        self.isFeatured = isFeatured
        self.steamID = steamID
        self.recipe = recipe
    }

    enum CodingKeys: String, CodingKey {
        case id, name, localizedNames, category, summary, rating, isFeatured, steamID, recipe
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        localizedNames = try c.decodeIfPresent([String: String].self, forKey: .localizedNames) ?? [:]
        category = try c.decodeIfPresent(String.self, forKey: .category) ?? ""
        summary = try c.decodeIfPresent(String.self, forKey: .summary) ?? ""
        rating = try c.decodeIfPresent(Rating.self, forKey: .rating) ?? .untested
        isFeatured = try c.decodeIfPresent(Bool.self, forKey: .isFeatured) ?? false
        steamID = try c.decodeIfPresent(Int.self, forKey: .steamID)
        recipe = try c.decodeIfPresent(Recipe.self, forKey: .recipe)
    }

    public var categoryPath: [String] { category.split(separator: "/").map(String.init) }

    /// Name in the user's preferred language, falling back to `name`.
    /// Language keys are matched without regard to case ("pt-br" == "pt-BR"),
    /// first the full code, then the base language.
    public func displayName(preferredLanguages: [String] = Locale.preferredLanguages) -> String {
        for language in preferredLanguages {
            let full = language.lowercased().replacingOccurrences(of: "_", with: "-")
            let base = String(full.split(separator: "-").first ?? Substring(full))
            for key in [full, base] {
                if let localized = localizedNames.first(where: { $0.key.lowercased() == key })?.value,
                   !localized.isEmpty {
                    return localized
                }
            }
        }
        return name
    }
}
