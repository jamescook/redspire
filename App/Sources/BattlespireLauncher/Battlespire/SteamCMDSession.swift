import Foundation

enum SteamCMDStage: Equatable {
    case running
    case done(gameDir: String)
    case failed(String)
}

/// Runs steamcmd interactively (its stdin piped) so the app can hand it a
/// password/Guard code as the user types them, without a separate Terminal
/// window. steamcmd's exact prompt wording isn't something this pattern-matches
/// against -- the user reads the live log and sends a response when asked,
/// same as they would at a real terminal.
@MainActor
final class SteamCMDSession: ObservableObject {
    @Published private(set) var stage: SteamCMDStage?
    @Published private(set) var log = ""
    @Published private(set) var isRunning = false

    private let runner: InteractiveProcessRunning
    private let steamCMDPath: () -> String?
    private let credentialStore: CredentialStore
    private let appID: String
    private let exeLabel: String
    private let findInstalledGameDir: (URL) -> String?
    private nonisolated(unsafe) var handle: InteractiveProcessHandle?

    private var pendingUsername = ""
    private var pendingPassword = ""
    private var pendingRememberPassword = false
    private var passwordSent = false

    /// `appID`/`findInstalledGameDir` default to Battlespire's own values so
    /// every existing call site is unaffected -- RedguardOnboardingWizard
    /// constructs this with Redguard's own AppID and exe-check instead of
    /// duplicating this whole session type.
    init(
        runner: InteractiveProcessRunning = SystemInteractiveProcessRunner(),
        steamCMDPath: @escaping () -> String? = { SteamCMDTool.executablePath },
        credentialStore: CredentialStore = KeychainCredentialStore(),
        appID: String = SteamCMDInstaller.appID,
        exeLabel: String = "GAME.EXE",
        findInstalledGameDir: @escaping (URL) -> String? = { SteamCMDInstaller.findInstalledGameDir(root: $0) }
    ) {
        self.runner = runner
        self.steamCMDPath = steamCMDPath
        self.credentialStore = credentialStore
        self.appID = appID
        self.exeLabel = exeLabel
        self.findInstalledGameDir = findInstalledGameDir
    }

    /// Pure mapping from the process outcome to the resulting UI stage.
    /// `exeLabel` names whichever file's absence means the install didn't
    /// really finish -- GAME.EXE for Battlespire, REDGUARD.EXE for Redguard.
    nonisolated static func resolveStage(
        exitCode: Int32, foundGameDir: String?, exeLabel: String = "GAME.EXE"
    ) -> SteamCMDStage {
        guard exitCode == 0 else {
            return .failed("steamcmd exited with status \(exitCode). See log above.")
        }
        guard let foundGameDir else {
            return .failed("steamcmd finished, but \(exeLabel) wasn't found in the install folder. See log above.")
        }
        return .done(gameDir: foundGameDir)
    }

    /// Pure: only save on an actual successful login+install, and only if
    /// the user opted in -- never persist a password that turned out wrong.
    nonisolated static func shouldSavePassword(stage: SteamCMDStage, rememberPassword: Bool) -> Bool {
        guard rememberPassword else { return false }
        if case .done = stage { return true }
        return false
    }

    /// Pure: has steamcmd's password prompt appeared in the log yet (and we
    /// haven't already answered it). "password:" is steamcmd's own literal,
    /// stable prompt text -- confirmed identical across both a plain-pipe
    /// run and a PTY run, unlike Steam Guard's prompt wording, which varies
    /// by account type. Waiting for the real prompt (rather than firing the
    /// password immediately on start) matters specifically under a PTY: the
    /// child reconfigures the terminal (echo off) before reading a password,
    /// and bytes written before that reconfiguration can be lost.
    nonisolated static func shouldSendPassword(log: String, alreadySent: Bool) -> Bool {
        !alreadySent && log.localizedCaseInsensitiveContains("password:")
    }

    /// `password` is never passed as a process argument (that'd leak it to
    /// anyone running `ps` on the machine) -- it's written straight to
    /// steamcmd's stdin instead, once its password prompt actually appears.
    func start(username: String, password: String, destDir: String, rememberPassword: Bool) {
        let user = username.trimmingCharacters(in: .whitespaces)
        guard !user.isEmpty else {
            stage = .failed("Enter your Steam username first.")
            return
        }
        guard let exe = steamCMDPath() else {
            stage = .failed("steamcmd isn't installed.")
            return
        }

        pendingUsername = user
        pendingPassword = password
        pendingRememberPassword = rememberPassword
        passwordSent = false

        log = ""
        stage = .running
        isRunning = true

        let args = [
            "+@sSteamCmdForcePlatformType", "windows",
            "+force_install_dir", destDir,
            "+login", user,
            "+app_update", appID, "validate",
            "+quit",
        ]

        handle = runner.start(
            executable: exe,
            arguments: args,
            onOutput: { [weak self] chunk in
                Task { @MainActor in
                    guard let self else { return }
                    self.log += chunk
                    if Self.shouldSendPassword(log: self.log, alreadySent: self.passwordSent) {
                        self.passwordSent = true
                        self.handle?.sendLine(password)
                    }
                }
            },
            onExit: { [weak self] exitCode in
                Task { @MainActor in self?.finish(exitCode: exitCode, destDir: destDir) }
            }
        )
    }

    func send(_ text: String) {
        handle?.sendLine(text)
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
        // Foundation's Process doesn't kill its child when the Swift wrapper
        // is deallocated -- without this, closing the wizard mid-run leaves
        // steamcmd running as an orphan indefinitely (confirmed via `ps`).
        handle?.terminate()
    }

    private func finish(exitCode: Int32, destDir: String) {
        isRunning = false
        handle = nil
        let found = findInstalledGameDir(URL(fileURLWithPath: destDir))
        let resolved = Self.resolveStage(exitCode: exitCode, foundGameDir: found, exeLabel: exeLabel)

        if Self.shouldSavePassword(stage: resolved, rememberPassword: pendingRememberPassword) {
            credentialStore.save(password: pendingPassword, for: pendingUsername)
        }

        stage = resolved
    }
}
