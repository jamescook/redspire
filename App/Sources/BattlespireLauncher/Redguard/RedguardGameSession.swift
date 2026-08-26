import Foundation

enum RedguardSessionError: LocalizedError {
    case backendNotInstalled(Backend)
    case redguardExeNotFound(String)
    case cdImageNotFound(String)

    var errorDescription: String? {
        switch self {
        case .backendNotInstalled(let backend):
            return "\(backend.displayName) isn't installed. Run: \(backend.installHint)"
        case .redguardExeNotFound(let dir):
            return "REDGUARD.EXE not found in \(dir)/Redguard. Point at the folder that contains the Redguard subfolder directly."
        case .cdImageNotFound(let dir):
            return "No CD image (.ins/.cue/.iso) found in \(dir). Pick one manually if it's named unusually."
        }
    }
}

/// Launches DOSBox for Redguard. Mirrors GameSession's shape, but Redguard's
/// actual layout genuinely differs: `gameDir` here is the folder mounted as
/// C: (containing both a `Redguard/` subfolder and `game.ins`), not the
/// folder GAME.EXE sits directly in like Battlespire -- confirmed via a real
/// GOG extraction and the manual dosbox-staging smoke test that first got
/// this game running at all. See RedguardGogInstaller and REDGUARD.md.
@MainActor
final class RedguardGameSession: ObservableObject {
    @Published private(set) var isRunning = false
    @Published var lastError: String?

    private var process: Process?

    /// Pure: the exact DOSBox argv for a launch, matching the config
    /// confirmed working end-to-end against both the GOG package and the
    /// raw retail disc during manual smoke testing.
    nonisolated static func buildArguments(gameDir: String, cdImage: String, backend: Backend, fullscreen: Bool, memsizeMB: Int) -> [String] {
        var args: [String] = []
        if backend == .x {
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
            "-c", "cd redguard",
            "-c", "rgfx.exe",
        ]
        return args
    }

    func play(gameDir: String, cdImagePathOverride: String, backend: Backend, fullscreen: Bool, memsizeMB: Int) {
        lastError = nil

        guard let exe = backend.executablePath else {
            lastError = RedguardSessionError.backendNotInstalled(backend).errorDescription
            return
        }

        let redguardExe = (gameDir as NSString).appendingPathComponent("Redguard/REDGUARD.EXE")
        guard FileManager.default.fileExists(atPath: redguardExe) else {
            lastError = RedguardSessionError.redguardExeNotFound(gameDir).errorDescription
            return
        }

        guard let cdImage = cdImagePathOverride.isEmpty
            ? CDImageDetector.autoDetect(inGameDir: gameDir)
            : cdImagePathOverride
        else {
            lastError = RedguardSessionError.cdImageNotFound(gameDir).errorDescription
            return
        }
        guard FileManager.default.fileExists(atPath: cdImage) else {
            lastError = RedguardSessionError.cdImageNotFound(gameDir).errorDescription
            return
        }

        let args = RedguardGameSession.buildArguments(gameDir: gameDir, cdImage: cdImage, backend: backend, fullscreen: fullscreen, memsizeMB: memsizeMB)

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
