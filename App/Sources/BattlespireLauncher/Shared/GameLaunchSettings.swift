import Foundation

/// One game's persisted launch settings, read as plain values via
/// GameMode.storageKeys instead of that mode's own @AppStorage-backed
/// ContentView -- lets a direct-launch trigger (Desktop shortcut) call
/// GameSession.play()/RedguardGameSession.play() with the exact same
/// settings the normal Play button would use, without instantiating that
/// View.
struct GameLaunchSettings {
    let gameDirectoryPath: String
    let cdImagePath: String
    let fullscreen: Bool
    let backend: Backend
    let memsizeMB: Int

    static func load(for mode: GameMode, defaults: UserDefaults = .standard) -> GameLaunchSettings {
        let keys = mode.storageKeys
        let backendRaw = defaults.string(forKey: keys.backend) ?? Backend.staging.rawValue
        let storedMemsize = defaults.object(forKey: keys.memsize) as? Int
        return GameLaunchSettings(
            gameDirectoryPath: defaults.string(forKey: keys.gameDirectory) ?? "",
            cdImagePath: defaults.string(forKey: keys.cdImage) ?? "",
            fullscreen: defaults.bool(forKey: keys.fullscreen),
            backend: Backend(rawValue: backendRaw) ?? .staging,
            memsizeMB: storedMemsize ?? keys.defaultMemsizeMB
        )
    }
}
