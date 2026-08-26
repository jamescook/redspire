import Testing
@testable import BattlespireLauncher

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
}
