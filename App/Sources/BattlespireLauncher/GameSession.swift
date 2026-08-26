import Foundation
import Combine

enum GameSessionError: LocalizedError {
    case backendNotInstalled(Backend)
    case gameExeNotFound(String)
    case cdImageNotFound(String)

    var errorDescription: String? {
        switch self {
        case .backendNotInstalled(let backend):
            return "\(backend.displayName) isn't installed. Run: \(backend.installHint)"
        case .gameExeNotFound(let dir):
            return "GAME.EXE not found in \(dir). Point at the folder that contains it directly."
        case .cdImageNotFound(let path):
            return "CD image not found at \(path)."
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
    /// Testable without spawning DOSBox.
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

        let cdImage = cdImagePathOverride.isEmpty
            ? (gameDir as NSString).appendingPathComponent("game.ins")
            : cdImagePathOverride
        guard FileManager.default.fileExists(atPath: cdImage) else {
            lastError = GameSessionError.cdImageNotFound(cdImage).errorDescription
            return
        }

        let args = GameSession.buildArguments(gameDir: gameDir, cdImage: cdImage, backend: backend, fullscreen: fullscreen, memsizeMB: memsizeMB)

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
