import Foundation

/// DOS is case-insensitive, and archives packaged from that side don't
/// necessarily match this app's casing (macOS's own filesystem sometimes
/// papers over that and sometimes doesn't) -- this checks explicitly rather
/// than relying on it. Shared across both games' disc/patch installers.
enum CaseInsensitiveFileLookup {
    /// Pure: the on-disk name matching `name` case-insensitively, if any.
    static func resolveActualName(
        in dir: String, matching name: String, fileManager: FileManager = .default
    ) -> String? {
        (try? fileManager.contentsOfDirectory(atPath: dir))?.first { $0.caseInsensitiveCompare(name) == .orderedSame }
    }
}
