import Foundation

/// Auto-detects a CD image inside a game folder by extension rather than a
/// fixed filename, since distributors disagree on naming -- GOG ships
/// game.ins, Steam ships Battlespire.ins for the same game. Prefers .ins
/// (has the redbook-audio track map), falls back to a bare .cue or .iso if
/// that's all a given install has. Shared across games -- the logic doesn't
/// depend on anything Battlespire- or Redguard-specific.
enum CDImageDetector {
    nonisolated static func autoDetect(inGameDir gameDir: String, fileManager: FileManager = .default) -> String? {
        guard let entries = try? fileManager.contentsOfDirectory(atPath: gameDir) else { return nil }
        for ext in ["ins", "cue", "iso"] {
            if let match = entries.first(where: { ($0 as NSString).pathExtension.lowercased() == ext }) {
                return (gameDir as NSString).appendingPathComponent(match)
            }
        }
        return nil
    }
}
