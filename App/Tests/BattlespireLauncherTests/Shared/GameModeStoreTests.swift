import Testing
import Foundation
@testable import Redspire

struct GameModeStoreTests {
    @Test func defaultsToBattlespireWhenNothingStored() throws {
        let store = UserDefaultsGameModeStore(defaults: makeIsolatedDefaults())
        #expect(store.loadMode() == .battlespire)
    }

    @Test func roundTripsSavedMode() throws {
        let store = UserDefaultsGameModeStore(defaults: makeIsolatedDefaults())
        store.save(mode: .redguard)
        #expect(store.loadMode() == .redguard)
    }

    @Test func fallsBackToBattlespireOnGarbageStoredValue() throws {
        let defaults = makeIsolatedDefaults()
        defaults.set("not-a-real-mode", forKey: "selectedGameMode")
        let store = UserDefaultsGameModeStore(defaults: defaults)
        #expect(store.loadMode() == .battlespire)
    }

    private func makeIsolatedDefaults() -> UserDefaults {
        let suiteName = "GameModeStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
