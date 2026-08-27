import Foundation

/// Which game the app is currently driving. Each case owns its own
/// distinctly-named settings keys in its content view -- adding a case here
/// never requires migrating another case's stored state.
enum GameMode: String, CaseIterable, Identifiable {
    case battlespire
    case redguard

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .battlespire: "Battlespire"
        case .redguard: "Redguard"
        }
    }

    /// SF Symbol fallback if the bundled icon file can't be loaded for any
    /// reason (see RootView.modeIcon).
    var systemImage: String {
        switch self {
        case .battlespire: "sparkles"
        case .redguard: "sun.max.fill"
        }
    }

    /// Bundled public-domain icon filename (see assets/icons/ATTRIBUTION.md
    /// for source/license of each).
    var iconFileName: String {
        switch self {
        case .battlespire: "battlespire-sword.svg"
        case .redguard: "redguard-scimitar.svg"
        }
    }

    /// The UserDefaults keys each mode's own ContentView stores its launch
    /// settings under (see ContentView/RedguardContentView's @AppStorage
    /// declarations, and AppDefaultsReset's matching key list). Exposed here
    /// so a trigger outside those Views -- a direct-launch URL from a
    /// Desktop shortcut -- can read the same persisted settings without
    /// instantiating the View. Adding a new mode means adding one case here;
    /// everything downstream (GameLaunchSettings, direct-launch dispatch)
    /// already works off this.
    struct StorageKeys {
        let gameDirectory: String
        let cdImage: String
        let fullscreen: String
        let backend: String
        let memsize: String
        let defaultMemsizeMB: Int
    }

    var storageKeys: StorageKeys {
        switch self {
        case .battlespire:
            return StorageKeys(
                gameDirectory: "gameDirectoryPath", cdImage: "cdImagePath", fullscreen: "fullscreen",
                backend: "backend", memsize: "memsizeMB", defaultMemsizeMB: 48
            )
        case .redguard:
            return StorageKeys(
                gameDirectory: "redguardGameDirectoryPath", cdImage: "redguardCdImagePath",
                fullscreen: "redguardFullscreen", backend: "redguardBackend",
                memsize: "redguardMemsizeMB", defaultMemsizeMB: 63
            )
        }
    }
}
