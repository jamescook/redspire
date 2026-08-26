import Testing
@testable import Redspire

struct SteamCMDSessionLogicTests {
    @Test func nonZeroExitFails() {
        let stage = SteamCMDSession.resolveStage(exitCode: 5, foundGameDir: nil)
        guard case .failed(let reason) = stage else { Issue.record("expected .failed"); return }
        #expect(reason.contains("5"))
    }

    @Test func zeroExitButNoGameDirFails() {
        let stage = SteamCMDSession.resolveStage(exitCode: 0, foundGameDir: nil)
        guard case .failed(let reason) = stage else { Issue.record("expected .failed"); return }
        #expect(reason.contains("GAME.EXE"))
    }

    /// Regression coverage: RedguardOnboardingWizard constructs this same
    /// session type with exeLabel: "REDGUARD.EXE" instead of duplicating
    /// the whole class -- the failure message must reflect that.
    @Test func exeLabelIsCustomizableForOtherGames() {
        let stage = SteamCMDSession.resolveStage(exitCode: 0, foundGameDir: nil, exeLabel: "REDGUARD.EXE")
        guard case .failed(let reason) = stage else { Issue.record("expected .failed"); return }
        #expect(reason.contains("REDGUARD.EXE"))
        #expect(!reason.contains("GAME.EXE"))
    }

    @Test func zeroExitWithGameDirSucceeds() {
        let stage = SteamCMDSession.resolveStage(exitCode: 0, foundGameDir: "/tmp/Steam")
        #expect(stage == .done(gameDir: "/tmp/Steam"))
    }

    @Test func savesOnlyWhenDoneAndOptedIn() {
        let done = SteamCMDStage.done(gameDir: "/tmp/Steam")
        let failed = SteamCMDStage.failed("nope")

        #expect(SteamCMDSession.shouldSavePassword(stage: done, rememberPassword: true))
        #expect(!SteamCMDSession.shouldSavePassword(stage: done, rememberPassword: false))
        #expect(!SteamCMDSession.shouldSavePassword(stage: failed, rememberPassword: true))
        #expect(!SteamCMDSession.shouldSavePassword(stage: .running, rememberPassword: true))
    }

    @Test func sendsPasswordOnlyOnceThePromptAppears() {
        #expect(!SteamCMDSession.shouldSendPassword(log: "Logging in user 'x' to Steam Public...", alreadySent: false))
        #expect(SteamCMDSession.shouldSendPassword(log: "Cached credentials not found.\n\npassword:", alreadySent: false))
        #expect(SteamCMDSession.shouldSendPassword(log: "PASSWORD:", alreadySent: false))
    }

    @Test func doesNotResendPasswordOnceAlreadySent() {
        #expect(!SteamCMDSession.shouldSendPassword(log: "password:", alreadySent: true))
    }
}
