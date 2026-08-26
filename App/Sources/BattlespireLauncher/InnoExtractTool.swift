import Foundation

/// Detection for `innoextract`, used to pull GOG's offline Inno Setup
/// installer apart without ever running the (Windows) installer itself.
enum InnoExtractTool {
    static let candidates = [
        "/opt/homebrew/bin/innoextract",
        "/usr/local/bin/innoextract",
    ]

    static var executablePath: String? {
        ExecutableLocator.firstExecutable(in: candidates)
    }

    static var isInstalled: Bool { executablePath != nil }
}
