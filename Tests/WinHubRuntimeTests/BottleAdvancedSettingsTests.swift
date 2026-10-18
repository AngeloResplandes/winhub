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
            ("A B=1", 1, .invalidVariableName("A B")),
            ("OK=1\nA\tB=1", 2, .invalidVariableName("A\tB")),
            ("OK=1\nWINEPREFIX=/tmp/x", 2, .reservedVariable("WINEPREFIX")),
            ("winePrefix=/tmp/x", 1, .reservedVariable("winePrefix")),
            ("A=1\nB=2\nA=3", 3, .duplicate("A")),
        ]
        for (text, line, reason) in cases {
            #expect(BottleAdvancedSettings.parseEnvironment(text) == .failure(.init(line: line, reason: reason)), "\(text)")
        }
    }

    @Test func variableErrorsOnlyMentionWhatVariablesRefuse() {
        let variable = AdvancedSettingsError(line: 1, reason: .invalidVariableName("A B")).errorDescription ?? ""
        let dll = AdvancedSettingsError(line: 1, reason: .invalidName("a,b")).errorDescription ?? ""
        #expect(variable != dll)
        #expect(!variable.contains("vírgula"))
        #expect(dll.contains("vírgula"))
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
            "xinput1_3.dll=n,b\n# note\n\nDINPUT8.DLL = b,n \nwinmm=n\nmscoree=\nole32.DLL=B").get()
        #expect(parsed == ["xinput1_3": "n,b", "dinput8": "b,n", "winmm": "n", "mscoree": "", "ole32": "b"])
    }

    @Test func overridesErrorsCarryTheLineNumber() {
        let cases: [(String, Int, AdvancedSettingsError.Reason)] = [
            ("winmm=n,b\nole32", 2, .missingEquals),
            ("=n", 1, .emptyName),
            (".dll=n", 1, .emptyName),
            ("my dll=n", 1, .invalidName("my dll")),
            ("a,b=n", 1, .invalidName("a,b")),
            ("a;b=n", 1, .invalidName("a;b")),
            ("winmm=x", 1, .invalidMode("x")),
            ("ok=n\nwinmm=n,n", 2, .invalidMode("n,n")),
            ("winmm=nb", 1, .invalidMode("nb")),
            ("winmm=n\n\nWINMM.dll=b", 3, .duplicate("winmm")),
        ]
        for (text, line, reason) in cases {
            #expect(BottleAdvancedSettings.parseOverrides(text) == .failure(.init(line: line, reason: reason)), "\(text)")
        }
    }

    @Test func overridesRefuseTheDLLsWinHubManages() {
        // An engine that picks the Direct3D would take these for leftovers of copied DLLs and remove them.
        let cases: [(String, Int, AdvancedSettingsError.Reason)] = [
            ("d3d11=n,b", 1, .managedDLL("d3d11")),
            ("winmm=n\nD3D10Core.dll=b", 2, .managedDLL("d3d10core")),
            ("dxgi=", 1, .managedDLL("dxgi")),
            ("winemetal=n", 1, .managedDLL("winemetal")),
        ]
        for (text, line, reason) in cases {
            #expect(BottleAdvancedSettings.parseOverrides(text) == .failure(.init(line: line, reason: reason)), "\(text)")
        }
        #expect(BottleAdvancedSettings.managedDLLs.isSuperset(of: GraphicsBackend.replacedDLLs))
        let description = AdvancedSettingsError(line: 1, reason: .managedDLL("d3d11")).errorDescription ?? ""
        #expect(description.contains("Gráficos (Direct3D)"))
    }

    @Test func editorHidesAndKeepsTheManagedOverrides() {
        // An older engine's DXVK, set by WinHub, next to the user's own override.
        let current = ["d3d11": "n,b", "d3d10core": "n,b", "xinput1_3": "n,b"]
        #expect(BottleAdvancedSettings.editableOverrides(current) == ["xinput1_3": "n,b"])
        #expect(BottleAdvancedSettings.overrides(["winmm": "n"], keepingManagedFrom: current)
            == ["winmm": "n", "d3d11": "n,b", "d3d10core": "n,b"])
        #expect(BottleAdvancedSettings.overrides([:], keepingManagedFrom: ["xinput1_3": "n"]).isEmpty)
    }

    @Test func overridesRoundTripSorted() throws {
        let overrides = ["winmm": "n", "xinput1_3": "n,b", "mscoree": ""]
        let text = BottleAdvancedSettings.formatOverrides(overrides)
        #expect(text == "mscoree=\nwinmm=n\nxinput1_3=n,b")
        #expect(try BottleAdvancedSettings.parseOverrides(text).get() == overrides)
    }

    @Test func errorDescriptionNamesTheLine() {
        let description = AdvancedSettingsError(line: 4, reason: .missingEquals).errorDescription ?? ""
        #expect(description.contains("4"))
    }
}
