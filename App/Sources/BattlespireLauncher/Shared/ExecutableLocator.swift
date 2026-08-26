import Foundation

/// Pure "pick the first candidate path that's an executable file" -- shared
/// by Backend, InnoExtractTool, and SteamCMDTool, which each just differ in
/// their candidate list. Testable with a fake predicate instead of touching
/// the real filesystem.
enum ExecutableLocator {
    static func firstExecutable(
        in candidates: [String],
        isExecutable: (String) -> Bool = { FileManager.default.isExecutableFile(atPath: $0) }
    ) -> String? {
        candidates.first(where: isExecutable)
    }
}
