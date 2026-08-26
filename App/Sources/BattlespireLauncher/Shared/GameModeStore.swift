import Foundation

/// Seam over which game is currently selected, so RootView's picker logic
/// can be tested against an in-memory fake instead of the real UserDefaults.
protocol GameModeStore {
    func loadMode() -> GameMode
    func save(mode: GameMode)
}

struct UserDefaultsGameModeStore: GameModeStore {
    private let key = "selectedGameMode"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Falls back to .battlespire both when nothing's stored yet (first
    /// launch under this feature) and when the stored value doesn't match
    /// any known case (e.g. a future downgrade after a case gets renamed).
    func loadMode() -> GameMode {
        guard let raw = defaults.string(forKey: key), let mode = GameMode(rawValue: raw) else {
            return .battlespire
        }
        return mode
    }

    func save(mode: GameMode) {
        defaults.set(mode.rawValue, forKey: key)
    }
}
