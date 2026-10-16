import Foundation
import Testing
@testable import WinHubRuntime

@Suite struct BottleAdvancedSettingsTests {
    // MARK: environment

    @Test func environmentKeepsValuesAndSkipsCommentsAndBlankLines() throws {
        let text = "# a note\nA=1\n\nC=\nD=a=b\r\n  E=  spaced\n   # indented comment"
        let parsed = try BottleAdvancedSettings.parseEnvironment(text).get()
        #expect(parsed == ["A": "1", "C": "", "D": "a=b", "E": "  spaced"])
        #expect(try BottleAdvancedSettings.parseEnvironment("").get().isEmpty)
    }

    @Test func environmentErrorsCarryTheLineNumber() {
        let cases: [(String, Int, AdvancedSettingsError.Reason)] = [
            ("OK=1\nNOEQUALS\nZ=2", 2, .missingEquals),
            ("# c\n\n=value", 3, .emptyName),
            ("A B=1", 1, .invalidName("A B")),
            ("OK=1\nA\tB=1", 2, .invalidName("A\tB")),
            ("A=1\nB=2\nA=3", 3, .duplicate("A")),
        ]
        for (text, line, reason) in cases {
            #expect(BottleAdvancedSettings.parseEnvironment(text) == .failure(.init(line: line, reason: reason)), "\(text)")
        }
    }

    @Test func environmentRoundTripsSorted() throws {
        let variables = ["ZED": "1", "ALPHA": "a=b", "EMPTY": ""]
        let text = BottleAdvancedSettings.formatEnvironment(variables)
        #expect(text == "ALPHA=a=b\nEMPTY=\nZED=1")
        #expect(try BottleAdvancedSettings.parseEnvironment(text).get() == variables)
        #expect(BottleAdvancedSettings.formatEnvironment([:]) == "")
    }

    // MARK: DLL overrides

    @Test func overridesNormalizeTheDLLName() throws {
        let parsed = try BottleAdvancedSettings.parseOverrides(
            "d3d11.dll=n,b\n# note\n\nDXGI.DLL = b,n \nwinmm=n\nmscoree=\nole32.DLL=B").get()
        #expect(parsed == ["d3d11": "n,b", "dxgi": "b,n", "winmm": "n", "mscoree": "", "ole32": "b"])
    }

    @Test func overridesErrorsCarryTheLineNumber() {
        let cases: [(String, Int, AdvancedSettingsError.Reason)] = [
            ("d3d11=n,b\nwinmm", 2, .missingEquals),
            ("=n", 1, .emptyName),
            (".dll=n", 1, .emptyName),
            ("my dll=n", 1, .invalidName("my dll")),
            ("a,b=n", 1, .invalidName("a,b")),
            ("a;b=n", 1, .invalidName("a;b")),
            ("d3d11=x", 1, .invalidMode("x")),
            ("ok=n\nd3d11=n,n", 2, .invalidMode("n,n")),
            ("d3d11=nb", 1, .invalidMode("nb")),
            ("d3d11=n\n\nD3D11.dll=b", 3, .duplicate("d3d11")),
        ]
        for (text, line, reason) in cases {
            #expect(BottleAdvancedSettings.parseOverrides(text) == .failure(.init(line: line, reason: reason)), "\(text)")
        }
    }

    @Test func overridesRoundTripSorted() throws {
        let overrides = ["winmm": "n", "d3d11": "n,b", "mscoree": ""]
        let text = BottleAdvancedSettings.formatOverrides(overrides)
        #expect(text == "d3d11=n,b\nmscoree=\nwinmm=n")
        #expect(try BottleAdvancedSettings.parseOverrides(text).get() == overrides)
    }

    @Test func errorDescriptionNamesTheLine() {
        let description = AdvancedSettingsError(line: 4, reason: .missingEquals).errorDescription ?? ""
        #expect(description.contains("4"))
    }
}
