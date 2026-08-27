import Foundation

/// Shells out to Homebrew to install a formula, streaming output back.
/// Only offered when brew itself is already present (see Backend.brewPath) --
/// this app never fetches/runs the Homebrew installer itself.
final class BrewInstaller {
    private let runner: ProcessRunning
    private let brewPath: () -> String?

    init(runner: ProcessRunning = SystemProcessRunner(), brewPath: @escaping () -> String? = { Backend.brewPath }) {
        self.runner = runner
        self.brewPath = brewPath
    }

    func install(
        formula: String,
        onOutput: @escaping @Sendable (String) -> Void,
        onComplete: @escaping @Sendable (Bool) -> Void
    ) {
        guard let brew = brewPath() else {
            onOutput("Homebrew not found.\n")
            onComplete(false)
            return
        }

        runner.runAsync(
            executable: brew,
            arguments: ["install", formula],
            onOutput: onOutput,
            onExit: { status in onComplete(status == 0) }
        )
    }
}
