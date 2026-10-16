import Foundation
import Testing
@testable import WinHubCore

@Suite struct ArgumentSplitterTests {
    @Test func splitsOnSpaces() {
        #expect(ArgumentSplitter.split("a b") == ["a", "b"])
        #expect(ArgumentSplitter.split("  a    b\tc  ") == ["a", "b", "c"])
        #expect(ArgumentSplitter.split("") == [])
        #expect(ArgumentSplitter.split("   ") == [])
    }

    @Test func respectsQuotes() {
        #expect(ArgumentSplitter.split("-x \"C:\\Program Files\\a\" b") == ["-x", "C:\\Program Files\\a", "b"])
        #expect(ArgumentSplitter.split("--name=\"a b\"") == ["--name=a b"])
        #expect(ArgumentSplitter.split("\"\" x") == ["", "x"])
    }

    @Test func escapedQuoteInsideDoubleQuotes() {
        #expect(ArgumentSplitter.split(#""say \"hi\" now" end"#) == [#"say "hi" now"#, "end"])
        // A backslash before anything else stays (Windows paths).
        #expect(ArgumentSplitter.split(#""C:\dir\" x"#) == [#"C:\dir" x"#])
        #expect(ArgumentSplitter.split(#"C:\dir\file"#) == [#"C:\dir\file"#])
        // Outside double quotes a backslash does not escape the quote that follows it.
        #expect(ArgumentSplitter.split(#"a\"b c"#) == [#"a\b c"#])
    }

    @Test func doesNotExpandTheShell() {
        #expect(ArgumentSplitter.split("$HOME ~ * `x`") == ["$HOME", "~", "*", "`x`"])
    }

    @Test func singleQuotesAreOrdinaryCharacters() {
        // As on Windows: they neither group words nor hide double quotes.
        #expect(ArgumentSplitter.split("'b c'") == ["'b", "c'"])
        #expect(ArgumentSplitter.split("it's \"a b\"") == ["it's", "a b"])
        #expect(ArgumentSplitter.split("'x \"y z\"'") == ["'x", "y z'"])
        #expect(ArgumentSplitter.split("\"it's here\"") == ["it's here"])
    }

    @Test func unclosedQuoteTakesTheRest() {
        #expect(ArgumentSplitter.split("a \"b c d") == ["a", "b c d"])
        #expect(ArgumentSplitter.split("'x y") == ["'x", "y"])
    }
}
