import Foundation
import Combine

enum GameSessionError: LocalizedError {
    case backendNotInstalled(Backend)
    case gameExeNotFound(String)
    case cdImageNotFound(String)
    case confResourceMissing

    var errorDescription: String? {
        switch self {
        case .backendNotInstalled(let backend):
            return "\(backend.displayName) isn't installed. Run: \(backend.installHint)"
        case .gameExeNotFound(let dir):
            return "GAME.EXE not found in \(dir). Point at the folder that contains it directly."
        case .cdImageNotFound(let dir):
            return "Couldn't find the game's music file (.ins/.cue/.iso) in \(dir). Pick one manually below if it's named unusually."
        case .confResourceMissing:
            return "Couldn't find this app's bundled DOSBox settings (battlespire.conf). Try reinstalling the app."
        }
    }
}

/// Launches DOSBox as a child process (rather than via `open`) so we hold a
/// live handle to it and get a real termination callback instead of polling.
@MainActor
final class GameSession: ObservableObject {
    @Published private(set) var isRunning = false
    @Published var lastError: String?

    private var process: Process?

    /// Pure: the exact DOSBox argv for a launch, mirroring play-battlespire.sh.
    /// Testable without spawning DOSBox. `confPath`, when given, is passed
    /// via -conf so the launch never silently depends on the user's own
    /// ambient dosbox-staging.conf -- see RedguardGameSession's identical
    /// parameter for the regression that motivated this.
    nonisolated static func buildArguments(gameDir: String, cdImage: String, backend: Backend, fullscreen: Bool, memsizeMB: Int, confPath: String?) -> [String] {
        var args: [String] = []
        if let confPath {
            args += ["-conf", confPath]
        }
        if backend == .dosboxX {
            args.append("-nopromptfolder")
        }
        args += ["--set", "dosbox memsize=\(memsizeMB)"]
        if fullscreen {
            args.append("--fullscreen")
        }
        args += [
            "-c", "MOUNT C \"\(gameDir)\"",
            "-c", "IMGMOUNT D \"\(cdImage)\" -t iso",
            "-c", "C:",
            "-c", "set causeway=MAXMEM:70;PRE:40;NAME:spire.swp",
            "-c", "game spire.cfg",
        ]
        return args
    }

    func play(gameDir: String, cdImagePathOverride: String, backend: Backend, fullscreen: Bool, memsizeMB: Int) {
        lastError = nil

        guard let exe = backend.executablePath else {
            lastError = GameSessionError.backendNotInstalled(backend).errorDescription
            return
        }

        let gameExe = (gameDir as NSString).appendingPathComponent("GAME.EXE")
        guard FileManager.default.fileExists(atPath: gameExe) else {
            lastError = GameSessionError.gameExeNotFound(gameDir).errorDescription
            return
        }

        guard let cdImage = cdImagePathOverride.isEmpty
            ? CDImageDetector.autoDetect(inGameDir: gameDir)
            : cdImagePathOverride
        else {
            lastError = GameSessionError.cdImageNotFound(gameDir).errorDescription
            return
        }
        guard FileManager.default.fileExists(atPath: cdImage) else {
            lastError = GameSessionError.cdImageNotFound(gameDir).errorDescription
            return
        }

        guard let confPath = BundledResource.url(named: "battlespire.conf")?.path else {
            lastError = GameSessionError.confResourceMissing.errorDescription
            return
        }

        let args = GameSession.buildArguments(gameDir: gameDir, cdImage: cdImage, backend: backend, fullscreen: fullscreen, memsizeMB: memsizeMB, confPath: confPath)

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: exe)
        proc.arguments = args
        proc.terminationHandler = { [weak self] _ in
            Task { @MainActor in
                self?.isRunning = false
                self?.process = nil
            }
        }

        do {
            try proc.run()
            process = proc
            isRunning = true
        } catch {
            lastError = "Failed to launch \(backend.displayName): \(error.localizedDescription)"
        }
    }

    func quit() {
        process?.terminate()
    }
}
