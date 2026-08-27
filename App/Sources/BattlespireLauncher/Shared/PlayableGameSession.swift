import Foundation

/// GameSession and RedguardGameSession already share this exact play()
/// shape -- this protocol just names that so RootView's direct-launch
/// dispatch (a Desktop shortcut reopening the app) can call either one
/// generically instead of switching on GameMode to pick a method.
@MainActor
protocol PlayableGameSession: AnyObject {
    var isRunning: Bool { get }
    func play(gameDir: String, cdImagePathOverride: String, backend: Backend, fullscreen: Bool, memsizeMB: Int)
}

extension GameSession: PlayableGameSession {}
extension RedguardGameSession: PlayableGameSession {}
