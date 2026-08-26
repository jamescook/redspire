import Testing
@testable import BattlespireLauncher

struct GameSessionArgumentsTests {
    @Test func stagingBackendOmitsNoPromptFolder() {
        let args = GameSession.buildArguments(gameDir: "/games/bs", cdImage: "/games/bs/game.ins", backend: .staging, fullscreen: false, memsizeMB: 48)
        #expect(!args.contains("-nopromptfolder"))
        #expect(args.contains("--fullscreen") == false)
    }

    @Test func xBackendIncludesNoPromptFolder() {
        let args = GameSession.buildArguments(gameDir: "/games/bs", cdImage: "/games/bs/game.ins", backend: .x, fullscreen: false, memsizeMB: 48)
        #expect(args.first == "-nopromptfolder")
    }

    @Test func fullscreenFlagIncluded() {
        let args = GameSession.buildArguments(gameDir: "/games/bs", cdImage: "/games/bs/game.ins", backend: .staging, fullscreen: true, memsizeMB: 48)
        #expect(args.contains("--fullscreen"))
    }

    @Test func mountAndImgmountCommandsAreWellFormed() {
        let args = GameSession.buildArguments(gameDir: "/games/My Battlespire", cdImage: "/games/My Battlespire/game.ins", backend: .staging, fullscreen: false, memsizeMB: 64)
        #expect(args.contains("dosbox memsize=64"))
        #expect(args.contains("MOUNT C \"/games/My Battlespire\""))
        #expect(args.contains("IMGMOUNT D \"/games/My Battlespire/game.ins\" -t iso"))
        #expect(args.contains("game spire.cfg"))
    }
}

struct BrewInstallerTests {
    @Test func successfulInstallReportsTrue() {
        let runner = FakeProcessRunner()
        runner.asyncOutputLines = ["Downloading...\n", "Installed.\n"]
        runner.asyncExitCode = 0
        let installer = BrewInstaller(runner: runner, brewPath: { "/opt/homebrew/bin/brew" })

        var output = ""
        var completed: Bool?
        installer.install(formula: "dosbox-staging", onOutput: { output += $0 }, onComplete: { completed = $0 })

        #expect(completed == true)
        #expect(output == "Downloading...\nInstalled.\n")
        #expect(runner.asyncCalls.first?.arguments == ["install", "dosbox-staging"])
    }

    @Test func failedInstallReportsFalse() {
        let runner = FakeProcessRunner()
        runner.asyncExitCode = 1
        let installer = BrewInstaller(runner: runner, brewPath: { "/opt/homebrew/bin/brew" })

        var completed: Bool?
        installer.install(formula: "dosbox-staging", onOutput: { _ in }, onComplete: { completed = $0 })

        #expect(completed == false)
    }

    @Test func missingBrewFailsWithoutTouchingRunner() {
        let runner = FakeProcessRunner()
        let installer = BrewInstaller(runner: runner, brewPath: { nil })

        var completed: Bool?
        installer.install(formula: "dosbox-staging", onOutput: { _ in }, onComplete: { completed = $0 })

        #expect(completed == false)
        #expect(runner.asyncCalls.isEmpty)
    }
}
