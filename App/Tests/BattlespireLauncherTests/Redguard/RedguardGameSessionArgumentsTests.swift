import Testing
@testable import BattlespireLauncher

struct RedguardGameSessionArgumentsTests {
    @Test func stagingBackendOmitsNoPromptFolder() {
        let args = RedguardGameSession.buildArguments(gameDir: "/games/rg", cdImage: "/games/rg/game.ins", backend: .staging, fullscreen: false, memsizeMB: 63)
        #expect(!args.contains("-nopromptfolder"))
        #expect(args.contains("--fullscreen") == false)
    }

    @Test func xBackendIncludesNoPromptFolder() {
        let args = RedguardGameSession.buildArguments(gameDir: "/games/rg", cdImage: "/games/rg/game.ins", backend: .x, fullscreen: false, memsizeMB: 63)
        #expect(args.first == "-nopromptfolder")
    }

    @Test func fullscreenFlagIncluded() {
        let args = RedguardGameSession.buildArguments(gameDir: "/games/rg", cdImage: "/games/rg/game.ins", backend: .staging, fullscreen: true, memsizeMB: 63)
        #expect(args.contains("--fullscreen"))
    }

    @Test func mountImgmountAndLaunchCommandsAreWellFormed() {
        let args = RedguardGameSession.buildArguments(gameDir: "/games/My Redguard", cdImage: "/games/My Redguard/game.ins", backend: .staging, fullscreen: false, memsizeMB: 63)
        #expect(args.contains("dosbox memsize=63"))
        #expect(args.contains("MOUNT C \"/games/My Redguard\""))
        #expect(args.contains("IMGMOUNT D \"/games/My Redguard/game.ins\" -t iso"))
        #expect(args.contains("cd redguard"))
        #expect(args.contains("rgfx.exe"))
    }
}
