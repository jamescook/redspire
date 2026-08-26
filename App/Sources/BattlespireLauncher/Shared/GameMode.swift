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

    // Placeholder SF Symbols -- real per-game icons are tracked separately
    // (battlespire-macos-ao9.5).
    var systemImage: String {
        switch self {
        case .battlespire: "sparkles"
        case .redguard: "sun.max.fill"
        }
    }
}
