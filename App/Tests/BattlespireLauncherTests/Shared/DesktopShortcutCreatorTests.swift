import Testing
import Foundation
@testable import Redspire

struct DesktopShortcutCreatorTests {
    @Test func invokesOsacompileWithTheGamesDirectLaunchURLAndReturnsTheAppPath() throws {
        let desktop = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: desktop) }
        let runner = FakeProcessRunner()
        runner.syncResult = (0, "")

        let appURL = try DesktopShortcutCreator.createShortcut(for: .battlespire, desktopURL: desktop, runner: runner)

        #expect(appURL == desktop.appendingPathComponent("Battlespire.app"))
        #expect(runner.syncCalls.count == 1)
        #expect(runner.syncCalls[0].executable == "/usr/bin/osacompile")
        #expect(runner.syncCalls[0].arguments[0] == "-o")
        #expect(runner.syncCalls[0].arguments[1] == appURL.path)
        #expect(runner.syncCalls[0].arguments.last?.contains("redspire://launch/battlespire") == true)
    }

    @Test func usesRedguardsOwnDirectLaunchURL() throws {
        let desktop = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: desktop) }
        let runner = FakeProcessRunner()
        runner.syncResult = (0, "")

        let appURL = try DesktopShortcutCreator.createShortcut(for: .redguard, desktopURL: desktop, runner: runner)

        #expect(appURL == desktop.appendingPathComponent("Redguard.app"))
        #expect(runner.syncCalls[0].arguments.last?.contains("redspire://launch/redguard") == true)
    }

    @Test func removesAStaleShortcutBeforeRecompiling() throws {
        // osacompile itself refuses to write over an existing path -- this
        // is the actual reason for the removeItem call, not just tidiness.
        let desktop = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: desktop) }
        let stalePath = desktop.appendingPathComponent("Battlespire.app")
        try FileManager.default.createDirectory(at: stalePath, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: stalePath.appendingPathComponent("stale-marker").path, contents: Data())

        let runner = FakeProcessRunner()
        runner.syncResult = (0, "")
        _ = try DesktopShortcutCreator.createShortcut(for: .battlespire, desktopURL: desktop, runner: runner)

        #expect(!FileManager.default.fileExists(atPath: stalePath.appendingPathComponent("stale-marker").path))
    }

    @Test func throwsWhenOsacompileFails() throws {
        let desktop = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: desktop) }
        let runner = FakeProcessRunner()
        runner.syncResult = (1, "syntax error")

        #expect(throws: DesktopShortcutError.self) {
            try DesktopShortcutCreator.createShortcut(for: .battlespire, desktopURL: desktop, runner: runner)
        }
    }

    // MARK: - isInstalled

    @Test func isInstalledFalseWhenNothingOnDesktop() throws {
        let desktop = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: desktop) }
        // Never touched -- isInstalled must short-circuit on the
        // file-existence check before ever spawning osadecompile.
        let runner = FakeProcessRunner()

        #expect(DesktopShortcutCreator.isInstalled(for: .battlespire, desktopURL: desktop, runner: runner) == false)
        #expect(runner.syncCalls.isEmpty)
    }

    @Test func isInstalledTrueWhenDecompiledScriptContainsTheModesURL() throws {
        let desktop = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: desktop) }
        FileManager.default.createFile(atPath: desktop.appendingPathComponent("Battlespire.app").path, contents: Data())
        let runner = FakeProcessRunner()
        runner.syncResult = (0, "open location \"redspire://launch/battlespire\"")

        #expect(DesktopShortcutCreator.isInstalled(for: .battlespire, desktopURL: desktop, runner: runner) == true)
    }

    @Test func isInstalledFalseWhenDecompiledScriptIsForADifferentMode() throws {
        // Guards against a stale Battlespire.app shortcut that used to
        // point somewhere else (e.g. before a URL scheme change) being
        // reported as installed just because a file with the right name
        // exists.
        let desktop = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: desktop) }
        FileManager.default.createFile(atPath: desktop.appendingPathComponent("Battlespire.app").path, contents: Data())
        let runner = FakeProcessRunner()
        runner.syncResult = (0, "open location \"redspire://launch/redguard\"")

        #expect(DesktopShortcutCreator.isInstalled(for: .battlespire, desktopURL: desktop, runner: runner) == false)
    }

    @Test func isInstalledFalseWhenOsadecompileFails() throws {
        let desktop = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: desktop) }
        FileManager.default.createFile(atPath: desktop.appendingPathComponent("Battlespire.app").path, contents: Data())
        let runner = FakeProcessRunner()
        runner.syncResult = (1, "")

        #expect(DesktopShortcutCreator.isInstalled(for: .battlespire, desktopURL: desktop, runner: runner) == false)
    }

    @Test func realOsacompileRoundTripsWithIsInstalled() throws {
        // No fakes here: proves the actual osacompile -> osadecompile round
        // trip this feature depends on genuinely works, not just that
        // FakeProcessRunner was told the right answer.
        let desktop = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: desktop) }

        #expect(DesktopShortcutCreator.isInstalled(for: .battlespire, desktopURL: desktop) == false)
        _ = try DesktopShortcutCreator.createShortcut(for: .battlespire, desktopURL: desktop)
        #expect(DesktopShortcutCreator.isInstalled(for: .battlespire, desktopURL: desktop) == true)
        #expect(DesktopShortcutCreator.isInstalled(for: .redguard, desktopURL: desktop) == false)
    }

    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
