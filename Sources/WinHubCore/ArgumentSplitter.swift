import Foundation

/// Splits a command line typed by the user into program arguments. No shell expansion happens.
public enum ArgumentSplitter {
    /// Splits on spaces and tabs. Double and single quotes group words; inside double quotes `\"` is a quote
    /// and any other backslash stays (Windows paths). An unclosed quote takes the rest of the line.
    public static func split(_ line: String) -> [String] {
        var arguments: [String] = []
        var current = ""
        var inArgument = false
        var quote: Character?
        var chars = line.makeIterator()
        var pending = chars.next()

        func finish() {
            if inArgument { arguments.append(current) }
            current = ""
            inArgument = false
        }

        while let char = pending {
            pending = chars.next()
            if let open = quote {
                if char == open {
                    quote = nil
                } else if char == "\\", open == "\"", pending == "\"" {
                    current.append("\"")
                    pending = chars.next()
                } else {
                    current.append(char)
                }
            } else if char == "\"" || char == "'" {
                quote = char
                inArgument = true
            } else if char == " " || char == "\t" || char == "\n" {
                finish()
            } else {
                current.append(char)
                inArgument = true
            }
        }
        finish()
        return arguments
    }
}

/// `NAME=value` lines (one variable per line) from a text box.
public enum EnvironmentLines {
    public struct InvalidLine: Error, Equatable, Sendable {
        /// The first line that is not `NAME=value`, trimmed.
        public let line: String

        public init(line: String) {
            self.line = line
        }
    }

    /// Empty lines are skipped. A name must not be empty and must not contain spaces or `=`.
    public static func parse(_ text: String) -> Result<[String: String], InvalidLine> {
        var variables: [String: String] = [:]
        for raw in text.split(whereSeparator: \.isNewline) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            guard let equals = line.firstIndex(of: "="), equals != line.startIndex else {
                return .failure(InvalidLine(line: line))
            }
            let name = line[..<equals]
            guard !name.contains(where: \.isWhitespace) else { return .failure(InvalidLine(line: line)) }
            variables[String(name)] = String(line[line.index(after: equals)...])
        }
        return .success(variables)
    }
}
