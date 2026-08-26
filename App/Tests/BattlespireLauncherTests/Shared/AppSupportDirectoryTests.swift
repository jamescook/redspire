import Testing
import Foundation
@testable import Redspire

struct AppSupportDirectoryTests {
    @Test func migratesLegacyFolderWhenCurrentDoesNotExist() throws {
        let base = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: base) }
        let legacy = base.appendingPathComponent("BattlespireLauncher")
        let current = base.appendingPathComponent("Redspire")
        try FileManager.default.createDirectory(at: legacy.appendingPathComponent("GOG"), withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: legacy.appendingPathComponent("GOG/GAME.EXE").path, contents: Data("game bytes".utf8))

        AppSupportDirectory.migrate(legacy: legacy, current: current)

        #expect(FileManager.default.fileExists(atPath: current.appendingPathComponent("GOG/GAME.EXE").path))
        #expect(!FileManager.default.fileExists(atPath: legacy.path))
    }

    /// Regression test for a real bug: the naive "rename whole folder only
    /// if the new one doesn't exist yet" version of this migration silently
    /// stranded real user data (a Steam install) once the new folder
    /// already existed with unrelated content (empty subfolders created by
    /// a test-isolation bug elsewhere, before this migration existed).
    @Test func mergesLegacyItemsWhenCurrentAlreadyExistsWithOtherContent() throws {
        let base = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: base) }
        let legacy = base.appendingPathComponent("BattlespireLauncher")
        let current = base.appendingPathComponent("Redspire")
        try FileManager.default.createDirectory(at: legacy.appendingPathComponent("steam"), withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: legacy.appendingPathComponent("steam/GAME.EXE").path, contents: Data("game bytes".utf8))
        try FileManager.default.createDirectory(at: current.appendingPathComponent("GOG"), withIntermediateDirectories: true)

        AppSupportDirectory.migrate(legacy: legacy, current: current)

        #expect(FileManager.default.fileExists(atPath: current.appendingPathComponent("steam/GAME.EXE").path))
        #expect(FileManager.default.fileExists(atPath: current.appendingPathComponent("GOG").path))
    }

    @Test func neverOverwritesSomethingAlreadyPresentUnderNewName() throws {
        let base = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: base) }
        let legacy = base.appendingPathComponent("BattlespireLauncher")
        let current = base.appendingPathComponent("Redspire")
        try FileManager.default.createDirectory(at: legacy.appendingPathComponent("GOG"), withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: legacy.appendingPathComponent("GOG/GAME.EXE").path, contents: Data("old bytes".utf8))
        try FileManager.default.createDirectory(at: current.appendingPathComponent("GOG"), withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: current.appendingPathComponent("GOG/GAME.EXE").path, contents: Data("new bytes".utf8))

        AppSupportDirectory.migrate(legacy: legacy, current: current)

        #expect(FileManager.default.contents(atPath: current.appendingPathComponent("GOG/GAME.EXE").path) == Data("new bytes".utf8))
    }

    @Test func doesNothingWhenNoLegacyFolderExists() throws {
        let base = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: base) }
        let current = base.appendingPathComponent("Redspire")

        AppSupportDirectory.migrate(legacy: base.appendingPathComponent("BattlespireLauncher"), current: current)

        #expect(!FileManager.default.fileExists(atPath: current.path))
    }

    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
