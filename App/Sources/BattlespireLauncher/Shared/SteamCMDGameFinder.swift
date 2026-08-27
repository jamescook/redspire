import Foundation

/// Looks for `exeRelativePath` at `root`, or one level down -- steamcmd's
/// depot layout for a given title isn't always confirmed ahead of time
/// (Battlespire's own comment on this predates any real depot download), so
/// this doesn't assume a fixed nesting depth. Shared between Battlespire's
/// and Redguard's steamcmd installers.
enum SteamCMDGameFinder {
    static func findInstalledGameDir(
        exeRelativePath: String, root: URL, fileManager: FileManager = .default
    ) -> String? {
        if fileManager.fileExists(atPath: root.appendingPathComponent(exeRelativePath).path) {
            return root.path
        }
        guard let children = try? fileManager.contentsOfDirectory(
            at: root, includingPropertiesForKeys: [.isDirectoryKey]
        ) else {
            return nil
        }
        for child in children {
            let isDir = (try? child.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            guard isDir else { continue }
            if fileManager.fileExists(atPath: child.appendingPathComponent(exeRelativePath).path) {
                return child.path
            }
        }
        return nil
    }
}
