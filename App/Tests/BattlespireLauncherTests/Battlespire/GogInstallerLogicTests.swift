import Testing
import Foundation
@testable import Redspire

struct GogInstallerLogicTests {
    // MARK: - rejectionMessage

    @Test func validInnoInstallerIsNotRejected() {
        #expect(GogInstaller.rejectionMessage(installerIsValidInno: true, sizeMB: 641) == nil)
    }

    @Test func smallInvalidFileIsFlaggedAsGalaxyStub() {
        let message = GogInstaller.rejectionMessage(installerIsValidInno: false, sizeMB: 0.47)
        #expect(message?.contains("Galaxy") == true)
    }

    @Test func largeInvalidFileGetsGenericMessage() {
        let message = GogInstaller.rejectionMessage(installerIsValidInno: false, sizeMB: 200)
        #expect(message?.contains("Galaxy") == false)
        #expect(message != nil)
    }

    // MARK: - resolveStage

    @Test func nonZeroExitFails() {
        let stage = GogInstaller.resolveStage(exitCode: 2, gameExeExists: false, versionString: nil, hashVerified: false, gameDir: "/tmp/x")
        guard case .failed(let reason) = stage else { Issue.record("expected .failed"); return }
        #expect(reason.contains("2"))
    }

    @Test func zeroExitButMissingGameExeFails() {
        let stage = GogInstaller.resolveStage(exitCode: 0, gameExeExists: false, versionString: nil, hashVerified: false, gameDir: "/tmp/x")
        guard case .failed = stage else { Issue.record("expected .failed"); return }
    }

    @Test func zeroExitWrongVersionFails() {
        let stage = GogInstaller.resolveStage(exitCode: 0, gameExeExists: true, versionString: "Battlespire V1.3", hashVerified: false, gameDir: "/tmp/x")
        guard case .failed(let reason) = stage else { Issue.record("expected .failed"); return }
        #expect(reason.contains("V1.3"))
    }

    @Test func successWithVerifiedHash() {
        let stage = GogInstaller.resolveStage(exitCode: 0, gameExeExists: true, versionString: "Battlespire V1.5", hashVerified: true, gameDir: "/tmp/x")
        #expect(stage == .done(gameDir: "/tmp/x", verifiedHash: true))
    }

    @Test func successWithUnverifiedHashStillSucceeds() {
        // A legitimate future GOG rebuild could have different bytes but
        // still be v1.5 -- the hash badge is informational, not a gate.
        let stage = GogInstaller.resolveStage(exitCode: 0, gameExeExists: true, versionString: "Battlespire V1.5", hashVerified: false, gameDir: "/tmp/x")
        #expect(stage == .done(gameDir: "/tmp/x", verifiedHash: false))
    }

    // MARK: - reset

    /// Real bug (same class as Redguard's installers): the wizard never
    /// called reset() on this object, so re-selecting "GOG" after any
    /// earlier attempt showed that stale stage/log instead of starting
    /// fresh.
    @Test @MainActor func resetClearsStageAndLogWhenNotRunning() async throws {
        // destinationRoot MUST be a throwaway temp dir here -- extract()
        // unconditionally wipes and recreates it, and this constructor arg
        // exists specifically so this test doesn't touch the user's real
        // ~/Library/Application Support (a real bug found live: an earlier
        // version of this test silently destroyed the user's actual
        // installed game files on every `swift test` run).
        let tempRoot = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempRoot) }
        let runner = FakeProcessRunner()
        runner.syncResult = (0, "")
        runner.asyncExitCode = 2
        runner.asyncOutputLines = ["some output\n"]
        let installer = GogInstaller(runner: runner, innoExtractPath: { "/usr/bin/true" }, destinationRoot: tempRoot)

        installer.extract(installerPath: "/tmp/fake.exe")
        await drainMainActorTasks()
        #expect(installer.stage != nil)
        #expect(installer.log != "")

        installer.reset()
        #expect(installer.stage == nil)
        #expect(installer.log == "")
    }

    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
