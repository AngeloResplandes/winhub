import Foundation

/// A compiled wildcard pattern: `*` matches any run of characters, `?`
/// matches one character and `\` escapes the next one. Matching is anchored
/// to the whole string and ignores case and diacritics (the same semantics as
/// Foundation's `NSPredicate` `LIKE[cd]`).
public struct WildcardPattern: Sendable, Equatable {
    enum Token: Sendable, Equatable {
        case literal(Character)
        case anyOne
        case anyRun
    }

    let tokens: [Token]

    public init(_ pattern: String) {
        var tokens: [Token] = []
        var escaping = false
        for character in Self.fold(pattern) {
            if escaping {
                tokens.append(.literal(character))
                escaping = false
                continue
            }
            switch character {
            case "\\": escaping = true
            case "*": if tokens.last != .anyRun { tokens.append(.anyRun) }
            case "?": tokens.append(.anyOne)
            default: tokens.append(.literal(character))
            }
        }
        if escaping { tokens.append(.literal("\\")) }
        self.tokens = tokens
    }

    public func matches(_ candidate: String) -> Bool {
        matches(folded: Array(Self.fold(candidate)))
    }

    /// Matches text already passed through `WildcardPattern.fold`.
    func matches(folded text: [Character]) -> Bool {
        var t = 0, p = 0
        var starToken: Int?
        var starText = 0

        while t < text.count {
            if p < tokens.count {
                switch tokens[p] {
                case .anyRun:
                    starToken = p
                    starText = t
                    p += 1
                    continue
                case .anyOne:
                    t += 1; p += 1
                    continue
                case .literal(let character) where character == text[t]:
                    t += 1; p += 1
                    continue
                default:
                    break
                }
            }
            // Mismatch: let the most recent `*` swallow one more character.
            guard let star = starToken else { return false }
            p = star + 1
            starText += 1
            t = starText
        }
        while p < tokens.count, tokens[p] == .anyRun { p += 1 }
        return p == tokens.count
    }

    static func fold(_ string: String) -> String {
        string.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
    }
}
