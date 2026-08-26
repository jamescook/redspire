import Foundation

/// Shells out to Homebrew to install a formula, streaming output back.
/// Only offered when brew itself is already present (see Backend.brewPath) --
/// this app never fetches/runs the Homebrew installer itself.
final class BrewInstaller {
    private let runner: ProcessRunning
    private let brewPath: () -> String?
    private var handle: ProcessHandle?

    init(runner: ProcessRunning = SystemProcessRunner(), brewPath: @escaping () -> String? = { Backend.brewPath }) {
        self.runner = runner
        self.brewPath = brewPath
    }

    func install(formula: String, onOutput: @escaping (String) -> Void, onComplete: @escaping (Bool) -> Void) {
        guard let brew = brewPath() else {
            onOutput("Homebrew not found.\n")
            onComplete(false)
            return
        }

        handle = runner.runAsync(
            executable: brew,
            arguments: ["install", formula],
            onOutput: onOutput,
            onExit: { [weak self] status in
                self?.handle = nil
                onComplete(status == 0)
            }
        )
    }
}
