import Testing
@testable import BattlespireLauncher

struct SteamInstallMethodTests {
    @Test func eachMethodRoutesToItsOwnDistinctScreen() {
        #expect(SteamInstallMethod.steamApp.screen == .steamViaApp)
        #expect(SteamInstallMethod.runCommandMyself.screen == .steamViaCommand)
        #expect(SteamInstallMethod.letAppDoIt.screen == .steamViaAutomatic)
    }

    @Test func allCasesMapToUniqueScreens() {
        let screens = SteamInstallMethod.allCases.map(\.screen)
        #expect(Set(screens).count == SteamInstallMethod.allCases.count)
    }
}
