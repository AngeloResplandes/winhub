import Foundation
import Testing
@testable import WinHubRuntime

@Suite struct BottleTemplateTests {
    let full: [GraphicsBackend] = [.auto, .wined3d, .dxvk, .dxmt]
    let r1: [GraphicsBackend] = [.wined3d, .dxmt]

    func bottle() -> Bottle {
        Bottle(name: "Teste", runtimeID: "r", windowsVersion: .win11, graphics: .dxvk, msync: false)
    }

    @Test func offersThreeTemplatesWithDistinctIDs() {
        #expect(BottleTemplate.all == [.games, .applications, .olderPrograms])
        #expect(Set(BottleTemplate.all.map(\.id)).count == 3)
        #expect(BottleTemplate.all.allSatisfy { !$0.title.isEmpty && !$0.help.isEmpty })
    }

    @Test func gamesTemplateWithFullEngine() {
        let result = BottleTemplate.games.apply(to: bottle(), availableGraphics: full, supportsMSync: true)
        #expect(result.windowsVersion == .win10)
        #expect(result.graphics == .auto)
        #expect(result.msync)
    }

    @Test func applicationsTemplateWithFullEngine() {
        var start = bottle()
        start.msync = true
        let result = BottleTemplate.applications.apply(to: start, availableGraphics: full, supportsMSync: true)
        #expect(result.windowsVersion == .win10)
        #expect(result.graphics == .wined3d)
        #expect(!result.msync)
    }

    @Test func olderProgramsTemplateWithFullEngine() {
        let result = BottleTemplate.olderPrograms.apply(to: bottle(), availableGraphics: full, supportsMSync: true)
        #expect(result.windowsVersion == .win7)
        #expect(result.graphics == .wined3d)
        #expect(!result.msync)
    }

    @Test func gamesFallsBackToFirstAvailableWithoutAuto() {
        let result = BottleTemplate.games.apply(to: bottle(), availableGraphics: r1, supportsMSync: true)
        #expect(result.graphics == .wined3d)
        let dxmtFirst = BottleTemplate.games.apply(to: bottle(), availableGraphics: [.dxmt, .wined3d], supportsMSync: true)
        #expect(dxmtFirst.graphics == .dxmt)
    }

    @Test func msyncStaysOffWithoutEngineSupport() {
        let result = BottleTemplate.games.apply(to: bottle(), availableGraphics: full, supportsMSync: false)
        #expect(!result.msync)
    }

    @Test func noAvailableGraphicsKeepsTheBottlesValue() {
        let result = BottleTemplate.games.apply(to: bottle(), availableGraphics: [], supportsMSync: true)
        #expect(result.graphics == .dxvk)
    }

    @Test func applyChangesOnlyTemplateFields() {
        var start = bottle()
        start.environment = ["A": "1"]
        start.performanceHUD = true
        let result = BottleTemplate.games.apply(to: start, availableGraphics: full, supportsMSync: true)
        #expect(result.id == start.id)
        #expect(result.name == start.name)
        #expect(result.environment == ["A": "1"])
        #expect(result.performanceHUD)
        #expect(result.folder == start.folder)
    }
}
