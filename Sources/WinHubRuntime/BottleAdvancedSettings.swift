import Foundation

/// A line of the "Avançado" text boxes that cannot be used, with its 1-based number.
public struct AdvancedSettingsError: Error, Equatable, Sendable, LocalizedError {
    public enum Reason: Equatable, Sendable {
        case missingEquals
        case emptyName
        /// A variable name with spaces (the first "=" ends the name).
        case invalidVariableName(String)
        /// A variable WinHub sets itself, such as `WINEPREFIX`.
        case reservedVariable(String)
        case invalidName(String)
        /// A DLL WinHub manages through the bottle's Direct3D choice.
        case managedDLL(String)
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
        case .invalidVariableName(let name):
            why = String(localized: "o nome “\(name)” não pode ter espaços nem “=”")
        case .reservedVariable(let name):
            why = String(localized: "“\(name)” é definida pelo WinHub e não pode ser mudada aqui")
        case .invalidName(let name):
            why = String(localized: "o nome “\(name)” não pode ter espaços, vírgulas nem ponto e vírgula")
        case .managedDLL(let name):
            why = String(localized: "“\(name)” é controlada pelo WinHub; escolha o Direct3D em “Gráficos (Direct3D)”")
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

    /// Variables WinHub sets itself; `WINEPREFIX` would point Wine at another prefix.
    static let reservedVariables: Set<String> = ["WINEPREFIX"]

    /// DLLs the bottle's Direct3D choice controls. With an engine that picks the Direct3D, an override on them
    /// looks like a leftover of the old copied DLLs and is removed (and Wine's DLLs copied back) before a program
    /// opens; with older engines, changing the Direct3D rewrites them.
    public static let managedDLLs: Set<String> = Set(GraphicsBackend.replacedDLLs + ["winemetal"])

    public static func parseEnvironment(_ text: String) -> Result<[String: String], AdvancedSettingsError> {
        var variables: [String: String] = [:]
        for (number, line) in entries(of: text) {
            guard let equals = line.firstIndex(of: "=") else {
                return .failure(.init(line: number, reason: .missingEquals))
            }
            let name = String(line[..<equals])
            if name.isEmpty { return .failure(.init(line: number, reason: .emptyName)) }
            if name.contains(where: \.isWhitespace) { return .failure(.init(line: number, reason: .invalidVariableName(name))) }
            if reservedVariables.contains(name.uppercased()) {
                return .failure(.init(line: number, reason: .reservedVariable(name)))
            }
            if variables[name] != nil { return .failure(.init(line: number, reason: .duplicate(name))) }
            variables[name] = String(line[line.index(after: equals)...])
        }
        return .success(variables)
    }

    /// `XInput1_3.dll=n,b` becomes `xinput1_3` = `n,b`. Names are lowercase without `.dll`; `managedDLLs` are refused.
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
            if managedDLLs.contains(name) { return .failure(.init(line: number, reason: .managedDLL(name))) }
            let mode = line[line.index(after: equals)...].filter { !$0.isWhitespace }.lowercased()
            if !overrideModes.contains(mode) { return .failure(.init(line: number, reason: .invalidMode(mode))) }
            if overrides[name] != nil { return .failure(.init(line: number, reason: .duplicate(name))) }
            overrides[name] = mode
        }
        return .success(overrides)
    }

    /// The overrides the editor shows: the ones of `managedDLLs` (set by WinHub for an older engine's Direct3D)
    /// stay out of it.
    public static func editableOverrides(_ overrides: [String: String]) -> [String: String] {
        overrides.filter { !managedDLLs.contains($0.key) }
    }

    /// `edited` plus the `managedDLLs` overrides of `current`, which the editor does not show.
    public static func overrides(_ edited: [String: String], keepingManagedFrom current: [String: String]) -> [String: String] {
        edited.merging(current.filter { managedDLLs.contains($0.key) }) { edited, _ in edited }
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
