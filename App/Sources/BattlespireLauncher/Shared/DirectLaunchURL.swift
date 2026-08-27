import Foundation

/// Parses the `redspire://launch/<mode>` URL a Desktop shortcut reopens the
/// app with (see DesktopShortcutCreator) into the GameMode it names. Kept
/// pure/free of Foundation-URL-scheme registration or notification-posting
/// side effects so it's trivially testable.
enum DirectLaunchURL {
    static let scheme = "redspire"
    static let host = "launch"

    nonisolated static func parse(_ url: URL) -> GameMode? {
        guard url.scheme == scheme, url.host == host else { return nil }
        let token = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return GameMode(rawValue: token)
    }

    nonisolated static func url(for mode: GameMode) -> URL {
        URL(string: "\(scheme)://\(host)/\(mode.rawValue)")!
    }
}
