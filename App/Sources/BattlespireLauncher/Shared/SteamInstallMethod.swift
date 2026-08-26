import Foundation

/// The three ways a wizard offers to get a Steam-owned game installed.
/// Game-agnostic content -- shared between Battlespire's and Redguard's
/// wizards, each of which maps a selection to its own screen enum locally.
enum SteamInstallMethod: String, CaseIterable, Identifiable {
    case steamApp
    case runCommandMyself
    case letAppDoIt

    var id: String { rawValue }

    var title: String {
        switch self {
        case .steamApp: return "Install it via the Steam app"
        case .runCommandMyself: return "I'll run steamcmd myself"
        case .letAppDoIt: return "Let this app run steamcmd for me"
        }
    }

    var subtitle: String {
        switch self {
        case .steamApp: return "Normal install through Steam's own app, then we detect it"
        case .runCommandMyself: return "We give you the exact command; you run it in Terminal"
        case .letAppDoIt: return "Enter your Steam login here; it downloads automatically"
        }
    }

    var icon: String {
        switch self {
        case .steamApp: return "gamecontroller"
        case .runCommandMyself: return "terminal"
        case .letAppDoIt: return "bolt.fill"
        }
    }
}
