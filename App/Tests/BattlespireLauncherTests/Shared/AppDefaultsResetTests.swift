import Testing
import Foundation
@testable import Redspire

struct AppDefaultsResetTests {
    @Test func clearsEveryKnownKey() throws {
        let suiteName = "AppDefaultsResetTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        for key in AppDefaultsReset.userDefaultsKeys {
            defaults.set("something", forKey: key)
        }

        AppDefaultsReset.reset(defaults: defaults, credentialStore: FakeCredentialStore())

        for key in AppDefaultsReset.userDefaultsKeys {
            #expect(defaults.object(forKey: key) == nil)
        }
    }

    @Test func leavesUnrelatedKeysAlone() throws {
        let suiteName = "AppDefaultsResetTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set("keep me", forKey: "someUnrelatedKey")

        AppDefaultsReset.reset(defaults: defaults, credentialStore: FakeCredentialStore())

        #expect(defaults.string(forKey: "someUnrelatedKey") == "keep me")
    }

    @Test func deletesEverySavedCredential() {
        let store = FakeCredentialStore()
        store.save(password: "hunter2", for: "alice")
        store.save(password: "swordfish", for: "bob")

        AppDefaultsReset.reset(defaults: UserDefaults(suiteName: "AppDefaultsResetTests-unused")!, credentialStore: store)

        #expect(store.listAccounts().isEmpty)
    }
}
