import Foundation

/// Splits a command line typed by the user into program arguments. No shell expansion happens.
public enum ArgumentSplitter {
    /// Splits on spaces and tabs. Only double quotes group words, as on Windows (a single quote is an ordinary
    /// character); inside them `\"` is a quote and any other backslash stays (Windows paths). An unclosed
    /// quote takes the rest of the line.
    public static func split(_ line: String) -> [String] {
        var arguments: [String] = []
        var current = ""
        var inArgument = false
        var inQuotes = false
        var chars = line.makeIterator()
        var pending = chars.next()

        func finish() {
            if inArgument { arguments.append(current) }
            current = ""
            inArgument = false
        }

        while let char = pending {
            pending = chars.next()
            if inQuotes {
                if char == "\"" {
                    inQuotes = false
                } else if char == "\\", pending == "\"" {
                    current.append("\"")
                    pending = chars.next()
                } else {
                    current.append(char)
                }
            } else if char == "\"" {
                inQuotes = true
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
