import Foundation

/// Whether a Redguard install folder has the files the game actually needs
/// to run. Unlike Battlespire's KnownGoodBuilds, this isn't a hash pinned to
/// one verified-good build -- there's no official Bethesda patch for
/// Redguard to certify a version against, and GOG's own REDGUARD.EXE has
/// changed MD5 across time without that being shown to matter. So this just
/// checks the install is actually complete, not that it's a specific
/// certified build.
enum RedguardInstallCheck {
    static func looksComplete(gameDir: String, fileManager: FileManager = .default) -> Bool {
        guard !gameDir.isEmpty else { return false }
        let redguardExe = (gameDir as NSString).appendingPathComponent("Redguard/REDGUARD.EXE")
        let rgfxExe = (gameDir as NSString).appendingPathComponent("Redguard/RGFX.EXE")
        return fileManager.fileExists(atPath: redguardExe) && fileManager.fileExists(atPath: rgfxExe)
    }
}
