import Testing
@testable import Redspire

struct RedguardGameSessionArgumentsTests {
    @Test func stagingBackendOmitsNoPromptFolder() {
        let args = RedguardGameSession.buildArguments(gameDir: "/games/rg", cdImage: "/games/rg/game.ins", backend: .staging, fullscreen: false, memsizeMB: 63, confPath: nil)
        #expect(!args.contains("-nopromptfolder"))
        #expect(args.contains("--fullscreen") == false)
    }

    @Test func xBackendIncludesNoPromptFolder() {
        let args = RedguardGameSession.buildArguments(gameDir: "/games/rg", cdImage: "/games/rg/game.ins", backend: .x, fullscreen: false, memsizeMB: 63, confPath: nil)
        #expect(args.first == "-nopromptfolder")
    }

    @Test func fullscreenFlagIncluded() {
        let args = RedguardGameSession.buildArguments(gameDir: "/games/rg", cdImage: "/games/rg/game.ins", backend: .staging, fullscreen: true, memsizeMB: 63, confPath: nil)
        #expect(args.contains("--fullscreen"))
    }

    @Test func mountImgmountAndLaunchCommandsAreWellFormed() {
        let args = RedguardGameSession.buildArguments(gameDir: "/games/My Redguard", cdImage: "/games/My Redguard/game.ins", backend: .staging, fullscreen: false, memsizeMB: 63, confPath: nil)
        #expect(args.contains("dosbox memsize=63"))
        #expect(args.contains("MOUNT C \"/games/My Redguard\""))
        #expect(args.contains("IMGMOUNT D \"/games/My Redguard/game.ins\" -t iso"))
        #expect(args.contains("cd redguard"))
        #expect(args.contains("rgfx.exe"))
    }

    /// Regression test: this used to never pass a conf file at all, so
    /// launches silently depended on whatever was in the user's own
    /// ambient dosbox-staging.conf -- a fixed cycle count left over from
    /// Battlespire-specific tuning there starved Redguard's much heavier
    /// Voodoo rendering, causing a real slowdown unrelated to this game's
    /// own install.
    @Test func confPathIsPassedFirstWhenGiven() {
        let args = RedguardGameSession.buildArguments(gameDir: "/games/rg", cdImage: "/games/rg/game.ins", backend: .staging, fullscreen: false, memsizeMB: 63, confPath: "/bundled/redguard.conf")
        #expect(args.first == "-conf")
        #expect(args[1] == "/bundled/redguard.conf")
    }

    @Test func omitsConfFlagWhenPathIsNil() {
        let args = RedguardGameSession.buildArguments(gameDir: "/games/rg", cdImage: "/games/rg/game.ins", backend: .staging, fullscreen: false, memsizeMB: 63, confPath: nil)
        #expect(!args.contains("-conf"))
    }
}
