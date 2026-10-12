import Foundation

/// How well a title is known to work, on a 0–5 scale shown as stars.
/// `unverified` marks ratings that come from a source WinHub does not trust.
public enum Rating: Int, Codable, Sendable, CaseIterable, Comparable {
    case unverified = -1
    case untested = 0
    case doesNotInstall = 1
    case installsButDoesNotRun = 2
    case limited = 3
    case good = 4
    case excellent = 5

    public init(clamping value: Int) {
        if value < 0 { self = .unverified }
        else { self = Rating(rawValue: min(value, 5)) ?? .excellent }
    }

    public var title: String {
        switch self {
        case .unverified: String(localized: "Fonte não confiável")
        case .untested: String(localized: "Sem teste")
        case .doesNotInstall: String(localized: "Não instala")
        case .installsButDoesNotRun: String(localized: "Instala, mas não abre")
        case .limited: String(localized: "Funciona com limitações")
        case .good: String(localized: "Bom")
        case .excellent: String(localized: "Excelente")
        }
    }

    public var stars: Int { max(rawValue, 0) }

    /// Titles hidden when the user turns off "Mostrar apps sem teste".
    public var isTested: Bool { self != .untested && self != .doesNotInstall }

    public static func < (lhs: Rating, rhs: Rating) -> Bool { lhs.rawValue < rhs.rawValue }
}
