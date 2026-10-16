import Foundation

/// A line of the "Avançado" text boxes that cannot be used, with its 1-based number.
public struct AdvancedSettingsError: Error, Equatable, Sendable, LocalizedError {
    public enum Reason: Equatable, Sendable {
        case missingEquals
        case emptyName
        case invalidName(String)
        case invalidMode(String)
        case duplicate(String)
    }

    public let line: Int
    public let reason: Reason

    public init(line: Int, reason: Reason) {
        self.line = line
        self.reason = reason
    }

    public var errorDescription: String? {
        let why: String
        switch reason {
        case .missingEquals:
            why = String(localized: "falta o sinal “=”")
        case .emptyName:
            why = String(localized: "o nome está vazio")
        case .invalidName(let name):
            why = String(localized: "o nome “\(name)” não pode ter espaços, vírgulas nem ponto e vírgula")
        case .invalidMode(let mode):
            why = String(localized: "o modo “\(mode)” não vale; use n, b, n,b ou b,n (vazio desliga a DLL)")
        case .duplicate(let name):
            why = String(localized: "“\(name)” já aparece em outra linha")
        }
        return String(localized: "Linha \(line): \(why).")
    }
}

/// Text form of a bottle's environment variables and DLL overrides, for the "Avançado" editor.
/// Both formats are one `name=value` per line; empty lines and `#` comments are skipped.
public enum BottleAdvancedSettings {
    /// Modes of a DLL override: native, builtin, both in either order, or empty (disabled).
    static let overrideModes: Set<String> = ["", "n", "b", "n,b", "b,n"]

    public static func parseEnvironment(_ text: String) -> Result<[String: String], AdvancedSettingsError> {
        var variables: [String: String] = [:]
        for (number, line) in entries(of: text) {
            guard let equals = line.firstIndex(of: "=") else {
                return .failure(.init(line: number, reason: .missingEquals))
            }
            let name = String(line[..<equals])
            if name.isEmpty { return .failure(.init(line: number, reason: .emptyName)) }
            if name.contains(where: \.isWhitespace) { return .failure(.init(line: number, reason: .invalidName(name))) }
            if variables[name] != nil { return .failure(.init(line: number, reason: .duplicate(name))) }
            variables[name] = String(line[line.index(after: equals)...])
        }
        return .success(variables)
    }

    /// `d3d11.dll=n,b` becomes `d3d11` = `n,b`. Names are lowercase without `.dll`.
    public static func parseOverrides(_ text: String) -> Result<[String: String], AdvancedSettingsError> {
        var overrides: [String: String] = [:]
        for (number, line) in entries(of: text) {
            guard let equals = line.firstIndex(of: "=") else {
                return .failure(.init(line: number, reason: .missingEquals))
            }
            var name = line[..<equals].trimmingCharacters(in: .whitespaces).lowercased()
            if name.hasSuffix(".dll") { name.removeLast(4) }
            if name.isEmpty { return .failure(.init(line: number, reason: .emptyName)) }
            if name.contains(where: { $0.isWhitespace || $0 == "," || $0 == ";" }) {
                return .failure(.init(line: number, reason: .invalidName(name)))
            }
            let mode = line[line.index(after: equals)...].filter { !$0.isWhitespace }.lowercased()
            if !overrideModes.contains(mode) { return .failure(.init(line: number, reason: .invalidMode(mode))) }
            if overrides[name] != nil { return .failure(.init(line: number, reason: .duplicate(name))) }
            overrides[name] = mode
        }
        return .success(overrides)
    }

    /// Sorted, so opening the editor and saving without edits changes nothing.
    public static func formatEnvironment(_ variables: [String: String]) -> String {
        variables.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: "\n")
    }

    public static func formatOverrides(_ overrides: [String: String]) -> String {
        formatEnvironment(overrides)
    }

    /// Lines worth reading with their 1-based numbers: trimmed, without blanks and comments.
    private static func entries(of text: String) -> [(Int, String)] {
        text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).enumerated().compactMap { index, raw in
            let line = raw.trimmingCharacters(in: .whitespaces)
            return line.isEmpty || line.hasPrefix("#") ? nil : (index + 1, line)
        }
    }
}
