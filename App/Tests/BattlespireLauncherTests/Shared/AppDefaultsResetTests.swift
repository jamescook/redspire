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

        AppDefaultsReset.reset(defaults: defaults, credentialStore: FakeCredentialStore(), desktopURL: try makeTempDir())

        for key in AppDefaultsReset.userDefaultsKeys {
            #expect(defaults.object(forKey: key) == nil)
        }
    }

    @Test func leavesUnrelatedKeysAlone() throws {
        let suiteName = "AppDefaultsResetTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set("keep me", forKey: "someUnrelatedKey")

        AppDefaultsReset.reset(defaults: defaults, credentialStore: FakeCredentialStore(), desktopURL: try makeTempDir())

        #expect(defaults.string(forKey: "someUnrelatedKey") == "keep me")
    }

    @Test func deletesEverySavedCredential() throws {
        let store = FakeCredentialStore()
        store.save(password: "hunter2", for: "alice")
        store.save(password: "swordfish", for: "bob")

        AppDefaultsReset.reset(
            defaults: UserDefaults(suiteName: "AppDefaultsResetTests-unused")!,
            credentialStore: store,
            desktopURL: try makeTempDir()
        )

        #expect(store.listAccounts().isEmpty)
    }

    /// desktopURL MUST be a throwaway temp dir in every test above too --
    /// without an explicit override, reset() defaults to the user's real
    /// ~/Desktop and would silently delete a real Battlespire.app/Redguard.app
    /// shortcut on every `swift test` run. Same real-bug class as
    /// RedguardDiscImageInstallerLogicTests' destinationRoot warning.
    @Test func deletesDesktopShortcutsForBothModes() throws {
        let desktop = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: desktop) }
        for mode in GameMode.allCases {
            FileManager.default.createFile(
                atPath: desktop.appendingPathComponent("\(mode.displayName).app").path, contents: Data()
            )
        }

        AppDefaultsReset.reset(
            defaults: UserDefaults(suiteName: "AppDefaultsResetTests-unused")!,
            credentialStore: FakeCredentialStore(),
            desktopURL: desktop
        )

        for mode in GameMode.allCases {
            #expect(!FileManager.default.fileExists(atPath: desktop.appendingPathComponent("\(mode.displayName).app").path))
        }
    }

    @Test func leavesUnrelatedDesktopFilesAlone() throws {
        let desktop = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: desktop) }
        let unrelated = desktop.appendingPathComponent("Some Other File.app")
        FileManager.default.createFile(atPath: unrelated.path, contents: Data())

        AppDefaultsReset.reset(
            defaults: UserDefaults(suiteName: "AppDefaultsResetTests-unused")!,
            credentialStore: FakeCredentialStore(),
            desktopURL: desktop
        )

        #expect(FileManager.default.fileExists(atPath: unrelated.path))
    }

    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
