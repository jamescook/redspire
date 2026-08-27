import Foundation

enum RedguardSessionError: LocalizedError {
    case backendNotInstalled(Backend)
    case redguardExeNotFound(String)
    case rgfxExeNotFound(String)
    case cdImageNotFound
    case confResourceMissing

    var errorDescription: String? {
        switch self {
        case .backendNotInstalled(let backend):
            return "\(backend.displayName) isn't installed. Run: \(backend.installHint)"
        case .redguardExeNotFound(let dir):
            return "REDGUARD.EXE not found in \(dir)/Redguard. Point at the folder that contains the Redguard subfolder directly."
        case .rgfxExeNotFound(let dir):
            return "RGFX.EXE (the game's renderer) not found in \(dir)/Redguard. Try reinstalling via the Setup Wizard."
        case .cdImageNotFound:
            return "This game also needs its second disc (for videos and music) to play. Add it under \"Second Disc\" above, then try again."
        case .confResourceMissing:
            return "Couldn't find this app's bundled DOSBox settings (redguard.conf). Try reinstalling the app."
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
    /// raw retail disc during manual smoke testing. `confPath`, when given,
    /// is passed via -conf so the launch never silently depends on the
    /// user's own ambient dosbox-staging.conf -- a real regression found
    /// live: cycles left over from Battlespire-specific tuning elsewhere in
    /// that same ambient config starved Redguard's much heavier rendering.
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

        let rgfxExe = (gameDir as NSString).appendingPathComponent("Redguard/RGFX.EXE")
        guard FileManager.default.fileExists(atPath: rgfxExe) else {
            lastError = RedguardSessionError.rgfxExeNotFound(gameDir).errorDescription
            return
        }

        guard let cdImage = cdImagePathOverride.isEmpty
            ? CDImageDetector.autoDetect(inGameDir: gameDir)
            : cdImagePathOverride
        else {
            lastError = RedguardSessionError.cdImageNotFound.errorDescription
            return
        }
        guard FileManager.default.fileExists(atPath: cdImage) else {
            lastError = RedguardSessionError.cdImageNotFound.errorDescription
            return
        }

        guard let confPath = BundledResource.url(named: "redguard.conf")?.path else {
            lastError = RedguardSessionError.confResourceMissing.errorDescription
            return
        }

        let args = RedguardGameSession.buildArguments(gameDir: gameDir, cdImage: cdImage, backend: backend, fullscreen: fullscreen, memsizeMB: memsizeMB, confPath: confPath)

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
