import Testing
@testable import Redspire

struct GameSessionArgumentsTests {
    @Test func stagingBackendOmitsNoPromptFolder() {
        let args = GameSession.buildArguments(gameDir: "/games/bs", cdImage: "/games/bs/game.ins", backend: .staging, fullscreen: false, memsizeMB: 48, confPath: nil)
        #expect(!args.contains("-nopromptfolder"))
        #expect(args.contains("--fullscreen") == false)
    }

    @Test func xBackendIncludesNoPromptFolder() {
        let args = GameSession.buildArguments(gameDir: "/games/bs", cdImage: "/games/bs/game.ins", backend: .x, fullscreen: false, memsizeMB: 48, confPath: nil)
        #expect(args.first == "-nopromptfolder")
    }

    @Test func fullscreenFlagIncluded() {
        let args = GameSession.buildArguments(gameDir: "/games/bs", cdImage: "/games/bs/game.ins", backend: .staging, fullscreen: true, memsizeMB: 48, confPath: nil)
        #expect(args.contains("--fullscreen"))
    }

    @Test func mountAndImgmountCommandsAreWellFormed() {
        let args = GameSession.buildArguments(gameDir: "/games/My Battlespire", cdImage: "/games/My Battlespire/game.ins", backend: .staging, fullscreen: false, memsizeMB: 64, confPath: nil)
        #expect(args.contains("dosbox memsize=64"))
        #expect(args.contains("MOUNT C \"/games/My Battlespire\""))
        #expect(args.contains("IMGMOUNT D \"/games/My Battlespire/game.ins\" -t iso"))
        #expect(args.contains("game spire.cfg"))
    }

    /// Regression test: neither GameSession nor RedguardGameSession used to
    /// pass a conf file at all, so launches silently depended on whatever
    /// was in the user's own ambient dosbox-staging.conf -- a fixed cycle
    /// count left over from tuning one game there broke the other.
    @Test func confPathIsPassedFirstWhenGiven() {
        let args = GameSession.buildArguments(gameDir: "/games/bs", cdImage: "/games/bs/game.ins", backend: .staging, fullscreen: false, memsizeMB: 48, confPath: "/bundled/battlespire.conf")
        #expect(args.first == "-conf")
        #expect(args[1] == "/bundled/battlespire.conf")
    }

    @Test func omitsConfFlagWhenPathIsNil() {
        let args = GameSession.buildArguments(gameDir: "/games/bs", cdImage: "/games/bs/game.ins", backend: .staging, fullscreen: false, memsizeMB: 48, confPath: nil)
        #expect(!args.contains("-conf"))
    }
}
