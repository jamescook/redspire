import Foundation

enum GogInstallStage: Equatable {
    case extracting
    case verifying
    case done(gameDir: String, verifiedHash: Bool)
    case failed(String)
}

/// Runs `innoextract` against a GOG offline installer, off the main thread,
/// streaming its (line-buffered) stdout back as progress so the UI never
/// blocks on a multi-hundred-MB extraction.
@MainActor
final class GogInstaller: ObservableObject {
    @Published private(set) var stage: GogInstallStage?
    @Published private(set) var log = ""
    @Published private(set) var isRunning = false

    private let runner: ProcessRunning
    private let innoExtractPath: () -> String?
    private nonisolated(unsafe) var handle: ProcessHandle?

    init(runner: ProcessRunning = SystemProcessRunner(), innoExtractPath: @escaping () -> String? = { InnoExtractTool.executablePath }) {
        self.runner = runner
        self.innoExtractPath = innoExtractPath
    }

    /// GOG's download page offers two different files for the same game: a
    /// small (~500KB) "GOG Galaxy" web-installer stub that just drives the
    /// Galaxy client to stream the game down, and the real "offline backup"
    /// installer (100s of MB, an actual Inno Setup archive) that innoextract
    /// can pull apart directly. Pure decision so it's testable without
    /// needing either real file on disk.
    nonisolated static func rejectionMessage(installerIsValidInno: Bool, sizeMB: Double) -> String? {
        guard !installerIsValidInno else { return nil }
        if sizeMB < 10 {
            return "This looks like GOG's small Galaxy web-installer (\(String(format: "%.1f", sizeMB)) MB), not the offline installer. On the GOG download page, look for an \"offline backup installer\" link (sometimes under a dropdown near the main download button) and use that setup_*.exe instead — it should be several hundred MB."
        }
        return "This doesn't look like a GOG Inno Setup installer innoextract can read."
    }

    /// Pure mapping from the extraction outcome to the resulting UI stage.
    nonisolated static func resolveStage(exitCode: Int32, gameExeExists: Bool, versionString: String?, hashVerified: Bool, gameDir: String) -> GogInstallStage {
        guard exitCode == 0 else {
            return .failed("innoextract exited with status \(exitCode). See log above.")
        }
        guard gameExeExists else {
            return .failed("Extraction finished, but GAME.EXE wasn't found at the expected location. This installer's layout may differ from the version this app was tested against.")
        }
        guard GameVersion.isV15(versionString) else {
            let found = versionString ?? "no version string found"
            return .failed("Extracted files don't look like v1.5 (\(found)).")
        }
        return .done(gameDir: gameDir, verifiedHash: hashVerified)
    }

    func extract(installerPath: String) {
        guard let exe = innoExtractPath() else {
            stage = .failed("innoextract isn't installed.")
            return
        }

        let sizeMB = (try? FileManager.default.attributesOfItem(atPath: installerPath)[.size] as? Int64).flatMap { $0 }
            .map { Double($0) / 1_048_576 } ?? 0
        let probe = runner.runSync(executable: exe, arguments: ["-l", installerPath])
        if let reason = Self.rejectionMessage(installerIsValidInno: probe.exitCode == 0, sizeMB: sizeMB) {
            stage = .failed(reason)
            return
        }

        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BattlespireLauncher", isDirectory: true)
        let dest = appSupport.appendingPathComponent("GOG", isDirectory: true)

        do {
            try? FileManager.default.removeItem(at: dest)
            try FileManager.default.createDirectory(at: dest, withIntermediateDirectories: true)
        } catch {
            stage = .failed("Couldn't prepare install folder: \(error.localizedDescription)")
            return
        }

        log = ""
        stage = .extracting
        isRunning = true

        handle = runner.runAsync(
            executable: exe,
            arguments: ["--gog", "--output-dir", dest.path, installerPath],
            onOutput: { [weak self] s in
                Task { @MainActor in self?.log += s }
            },
            onExit: { [weak self] exitCode in
                Task { @MainActor in self?.finish(exitCode: exitCode, dest: dest) }
            }
        )
    }

    private func finish(exitCode: Int32, dest: URL) {
        isRunning = false
        handle = nil

        if exitCode == 0 {
            stage = .verifying
        }

        let gameExe = dest.appendingPathComponent("GAME.EXE").path
        let exists = FileManager.default.fileExists(atPath: gameExe)
        let versionString = exists ? GameVersion.detect(gameExePath: gameExe) : nil
        let verified = exists && KnownGoodBuilds.isVerified(gameExePath: gameExe)

        stage = Self.resolveStage(
            exitCode: exitCode,
            gameExeExists: exists,
            versionString: versionString,
            hashVerified: verified,
            gameDir: dest.path
        )
    }

    func cancel() {
        handle?.terminate()
    }

    /// No-op while actually running -- never silently hides an in-progress
    /// attempt's visible state just because the wizard navigated away and
    /// back to this screen.
    func reset() {
        guard !isRunning else { return }
        stage = nil
        log = ""
    }

    deinit {
        // See SteamCMDSession's deinit -- Foundation's Process doesn't kill
        // its child on dealloc; without this, closing the wizard mid-extract
        // leaves innoextract running as an orphan.
        handle?.terminate()
    }
}
