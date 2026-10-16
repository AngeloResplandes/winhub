import Foundation
import Testing

/// Checks the interface's String Catalog (Sources/WinHub/Resources/Localizable.xcstrings).
@Suite struct LocalizationTests {
    static let catalog = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appending(path: "Sources/WinHub/Resources/Localizable.xcstrings")

    /// `%@`, `%lld`, `%1$@`… with the positions dropped, sorted, so reordered translations compare equal.
    static func specifiers(_ text: String) -> [String] {
        let pattern = /%(?:\d+\$)?(@|l{0,2}d|l{0,2}u|f|%)/
        return text.matches(of: pattern).map { String($0.output.1) }.filter { $0 != "%" }.sorted()
    }

    /// Every value of a localization: its string unit, or each plural form.
    static func values(_ localization: [String: Any]) -> [String] {
        if let unit = localization["stringUnit"] as? [String: Any], let value = unit["value"] as? String { return [value] }
        let plural = (localization["variations"] as? [String: Any])?["plural"] as? [String: Any] ?? [:]
        return plural.values.compactMap { (($0 as? [String: Any])?["stringUnit"] as? [String: Any])?["value"] as? String }
    }

    /// Languages every interface string must be translated into (the source, Brazilian Portuguese, needs none).
    static let languages = ["en", "es"]

    @Test(arguments: languages) func everyStringIsTranslatedWithTheSameArguments(language: String) throws {
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: Self.catalog)) as? [String: Any]
        #expect(json?["sourceLanguage"] as? String == "pt")
        let strings = try #require(json?["strings"] as? [String: [String: Any]])
        #expect(!strings.isEmpty)
        for (key, entry) in strings where entry["extractionState"] as? String != "stale" {
            let localizations = entry["localizations"] as? [String: Any] ?? [:]
            let translation = try #require(localizations[language] as? [String: Any], "no \(language) for “\(key)”")
            let values = Self.values(translation)
            #expect(!values.isEmpty, "empty \(language) for “\(key)”")
            for value in values {
                // Plural forms may spell the number out ("one title"), so they only must not add arguments.
                if translation["variations"] != nil {
                    #expect(Set(Self.specifiers(value)).isSubset(of: Set(Self.specifiers(key))),
                            "\(language) “\(value)” for “\(key)”")
                } else {
                    #expect(Self.specifiers(value) == Self.specifiers(key), "\(language) “\(value)” for “\(key)”")
                }
            }
        }
    }
}
