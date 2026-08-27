import Foundation

/// Everything "Reset to Defaults" (File menu) clears -- both games' saved
/// settings plus any remembered Steam passwords. Deliberately does NOT
/// touch installed game files under Application Support; that's a much
/// bigger, harder-to-undo action than resetting preferences, and isn't what
/// "reset to defaults" implies in normal app UX.
enum AppDefaultsReset {
    /// Explicit list rather than derived, so adding a new @AppStorage key
    /// elsewhere is a deliberate addition here too.
    static let userDefaultsKeys: [String] = [
        "gameDirectoryPath", "cdImagePath", "fullscreen", "backend", "memsizeMB", "wizardCompleted",
        "redguardGameDirectoryPath", "redguardCdImagePath", "redguardFullscreen", "redguardBackend",
        "redguardMemsizeMB", "redguardWizardCompleted",
        "selectedGameMode",
    ]

    static func reset(defaults: UserDefaults = .standard, credentialStore: CredentialStore = KeychainCredentialStore()) {
        for key in userDefaultsKeys {
            defaults.removeObject(forKey: key)
        }
        for account in credentialStore.listAccounts() {
            credentialStore.delete(account: account)
        }
    }
}
