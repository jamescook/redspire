import Foundation

enum Backend: String, CaseIterable, Identifiable {
    case staging
    case x

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .staging: return "dosbox-staging"
        case .x: return "dosbox-x"
        }
    }

    /// Homebrew installs its binaries under a different prefix on Apple
    /// Silicon vs. Intel, and a GUI .app launched from Finder doesn't
    /// inherit the shell's PATH -- so both are checked explicitly rather
    /// than relying on `which`.
    static let stagingCandidates = [
        "/opt/homebrew/bin/dosbox-staging",
        "/usr/local/bin/dosbox-staging",
    ]

    static let xCandidate = "/Applications/dosbox-x.app/Contents/MacOS/DOSBox-X"

    static let brewCandidates = [
        "/opt/homebrew/bin/brew",
        "/usr/local/bin/brew",
    ]

    /// Resolved path to this backend's executable, or nil if not installed.
    var executablePath: String? {
        switch self {
        case .staging:
            return Backend.stagingCandidates.first { FileManager.default.isExecutableFile(atPath: $0) }
        case .x:
            return FileManager.default.isExecutableFile(atPath: Backend.xCandidate) ? Backend.xCandidate : nil
        }
    }

    var isInstalled: Bool { executablePath != nil }

    var installHint: String {
        switch self {
        case .staging: return "brew install dosbox-staging"
        case .x: return "brew install --cask dosbox-x-app"
        }
    }

    static var brewPath: String? {
        brewCandidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }
}
