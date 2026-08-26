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
}
