import Foundation

/// Catalog search:
///
/// 1. The query is trimmed and split on whitespace; the words must appear in
///    the name in the order typed (`half life` → `*half*life*`), ignoring case
///    and accents.
/// 2. Without a query the featured titles are shown.
/// 3. Untested titles can be hidden; results are sorted by name in natural
///    order ("Game 9" before "Game 10") and capped at `resultLimit`.
public struct CatalogSearchEngine: Sendable {
    public static let defaultResultLimit = 128

    public struct Options: Sendable, Equatable {
        public var showUntested: Bool
        public var resultLimit: Int

        public init(showUntested: Bool = true, resultLimit: Int = CatalogSearchEngine.defaultResultLimit) {
            self.showUntested = showUntested
            self.resultLimit = resultLimit
        }
    }

    public struct Result: Sendable, Equatable {
        public var entries: [CatalogEntry]
        /// True when no query was typed and the featured list is shown.
        public var isFeatured: Bool
        /// Matches before the result limit was applied.
        public var totalMatches: Int
        public var catalogCount: Int

        public var showsNoResults: Bool { catalogCount > 0 && entries.isEmpty }
        public var isTruncated: Bool { totalMatches > entries.count }
    }

    public let entries: [CatalogEntry]
    /// Names in the user's language; these are what the search matches and sorts.
    public let searchNames: [String]
    private let foldedNames: [[Character]]

    public init(entries: [CatalogEntry], preferredLanguages: [String] = Locale.preferredLanguages) {
        self.entries = entries.filter { !$0.name.isEmpty }
        self.searchNames = self.entries.map { $0.displayName(preferredLanguages: preferredLanguages) }
        self.foldedNames = searchNames.map { Array(WildcardPattern.fold($0)) }
    }

    /// Builds the wildcard pattern from raw search-field text, or `nil` for an empty query.
    public static func likePattern(for query: String) -> String? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        var pattern = "*"
        for word in trimmed.components(separatedBy: .whitespacesAndNewlines) where !word.isEmpty {
            // Typed wildcard characters are matched literally.
            let escaped = word
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "*", with: "\\*")
                .replacingOccurrences(of: "?", with: "\\?")
            pattern += escaped + "*"
        }
        return pattern
    }

    public func search(_ query: String, options: Options = Options()) -> Result {
        let pattern = Self.likePattern(for: query).map(WildcardPattern.init)

        var matches: [Int] = []
        for index in entries.indices {
            let entry = entries[index]
            if !options.showUntested && !entry.rating.isTested { continue }
            let isMatch = pattern.map { $0.matches(folded: foldedNames[index]) } ?? entry.isFeatured
            if isMatch { matches.append(index) }
        }
        matches.sort { searchNames[$0].localizedStandardCompare(searchNames[$1]) == .orderedAscending }

        return Result(
            entries: matches.prefix(max(options.resultLimit, 0)).map { entries[$0] },
            isFeatured: pattern == nil,
            totalMatches: matches.count,
            catalogCount: entries.count
        )
    }
}
