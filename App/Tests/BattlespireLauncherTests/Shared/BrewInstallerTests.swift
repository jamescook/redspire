import Testing
@testable import BattlespireLauncher

struct BrewInstallerTests {
    @Test func successfulInstallReportsTrue() {
        let runner = FakeProcessRunner()
        runner.asyncOutputLines = ["Downloading...\n", "Installed.\n"]
        runner.asyncExitCode = 0
        let installer = BrewInstaller(runner: runner, brewPath: { "/opt/homebrew/bin/brew" })

        nonisolated(unsafe) var output = ""
        nonisolated(unsafe) var completed: Bool?
        installer.install(formula: "dosbox-staging", onOutput: { output += $0 }, onComplete: { completed = $0 })

        #expect(completed == true)
        #expect(output == "Downloading...\nInstalled.\n")
        #expect(runner.asyncCalls.first?.arguments == ["install", "dosbox-staging"])
    }

    @Test func failedInstallReportsFalse() {
        let runner = FakeProcessRunner()
        runner.asyncExitCode = 1
        let installer = BrewInstaller(runner: runner, brewPath: { "/opt/homebrew/bin/brew" })

        nonisolated(unsafe) var completed: Bool?
        installer.install(formula: "dosbox-staging", onOutput: { _ in }, onComplete: { completed = $0 })

        #expect(completed == false)
    }

    @Test func missingBrewFailsWithoutTouchingRunner() {
        let runner = FakeProcessRunner()
        let installer = BrewInstaller(runner: runner, brewPath: { nil })

        nonisolated(unsafe) var completed: Bool?
        installer.install(formula: "dosbox-staging", onOutput: { _ in }, onComplete: { completed = $0 })

        #expect(completed == false)
        #expect(runner.asyncCalls.isEmpty)
    }
}
