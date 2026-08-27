import Foundation

/// The app's own root folder under ~/Library/Application Support, shared by
/// every installer (both games) as the parent of their own install
/// destinations.
enum AppSupportDirectory {
    static let name = "Redspire"

    static var root: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(name, isDirectory: true)
    }

    /// One-time migration from the app's previous name (BattlespireLauncher)
    /// to its real ~/Library/Application Support location.
    static func migrateFromLegacyNameIfNeeded(fileManager: FileManager = .default) {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        migrate(
            legacy: base.appendingPathComponent("BattlespireLauncher", isDirectory: true),
            current: base.appendingPathComponent(name, isDirectory: true),
            fileManager: fileManager
        )
    }

    /// Merges `legacy`'s contents into `current` item by item (not a single
    /// directory move) so installs/extractions survive the rename even if
    /// `current` already exists with some content of its own (e.g. empty
    /// subfolders created before this migration existed). Never overwrites
    /// something already present under the new name. `legacy`/`current` are
    /// injectable so this can be tested against real temp directories
    /// instead of the app's real ~/Library/Application Support location.
    static func migrate(legacy: URL, current: URL, fileManager: FileManager = .default) {
        guard fileManager.fileExists(atPath: legacy.path) else { return }

        if !fileManager.fileExists(atPath: current.path) {
            try? fileManager.moveItem(at: legacy, to: current)
            return
        }

        guard let items = try? fileManager.contentsOfDirectory(atPath: legacy.path) else { return }
        for item in items {
            let from = legacy.appendingPathComponent(item)
            let dest = current.appendingPathComponent(item)
            guard !fileManager.fileExists(atPath: dest.path) else { continue }
            try? fileManager.moveItem(at: from, to: dest)
        }
    }
}
