import Foundation

/// Looks up a bundled resource file by its exact on-disk name (all `.copy`
/// resources flatten to the bundle root regardless of source subfolder).
/// build.sh copies these into the real app's Contents/Resources/ directly
/// (SPM's generated resource bundle has no Info.plist, which codesign
/// refuses to validate as a nested bundle) -- check there first, falling
/// back to Bundle.module for local `swift build`/`swift test` runs, which
/// don't produce a real .app at all. Shared between Battlespire's and
/// Redguard's disc-image installers.
enum BundledResource {
    static func url(named name: String, fileManager: FileManager = .default) -> URL? {
        if let resourceURL = Bundle.main.resourceURL {
            let candidate = resourceURL.appendingPathComponent(name)
            if fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        return Bundle.module.url(forResource: name, withExtension: nil)
    }
}
