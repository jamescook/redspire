import Testing
import Foundation
@testable import Redspire

struct GameLaunchSettingsTests {
    @Test func loadsBattlespireDefaultsWhenNothingStored() throws {
        let (defaults, suiteName) = try makeSuite()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = GameLaunchSettings.load(for: .battlespire, defaults: defaults)

        #expect(settings.gameDirectoryPath == "")
        #expect(settings.cdImagePath == "")
        #expect(settings.fullscreen == false)
        #expect(settings.backend == .staging)
        #expect(settings.memsizeMB == 48)
    }

    @Test func loadsRedguardDefaultsWhenNothingStored() throws {
        let (defaults, suiteName) = try makeSuite()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = GameLaunchSettings.load(for: .redguard, defaults: defaults)

        // Redguard's own default (63MB) differs from Battlespire's (48MB) --
        // see RedguardContentView's @AppStorage default. A shared fallback
        // here would silently override that per-game tuning.
        #expect(settings.memsizeMB == 63)
    }

    @Test func loadsStoredValuesPerMode() throws {
        let (defaults, suiteName) = try makeSuite()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set("/games/battlespire", forKey: "gameDirectoryPath")
        defaults.set("/discs/music.iso", forKey: "cdImagePath")
        defaults.set(true, forKey: "fullscreen")
        defaults.set(Backend.dosboxX.rawValue, forKey: "backend")
        defaults.set(96, forKey: "memsizeMB")

        let settings = GameLaunchSettings.load(for: .battlespire, defaults: defaults)

        #expect(settings.gameDirectoryPath == "/games/battlespire")
        #expect(settings.cdImagePath == "/discs/music.iso")
        #expect(settings.fullscreen == true)
        #expect(settings.backend == .dosboxX)
        #expect(settings.memsizeMB == 96)
    }

    @Test func battlespireAndRedguardSettingsDontLeakIntoEachOther() throws {
        let (defaults, suiteName) = try makeSuite()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set("/games/battlespire", forKey: "gameDirectoryPath")
        defaults.set("/games/redguard", forKey: "redguardGameDirectoryPath")

        #expect(GameLaunchSettings.load(for: .battlespire, defaults: defaults).gameDirectoryPath == "/games/battlespire")
        #expect(GameLaunchSettings.load(for: .redguard, defaults: defaults).gameDirectoryPath == "/games/redguard")
    }

    private func makeSuite() throws -> (defaults: UserDefaults, suiteName: String) {
        let suiteName = "GameLaunchSettingsTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        return (defaults, suiteName)
    }
}
