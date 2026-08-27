import Foundation

enum Backend: String, CaseIterable, Identifiable {
    case staging
    // Explicit rawValue "x" (not derived from the case name) so renaming
    // this identifier for lint compliance doesn't silently change the
    // string persisted via @AppStorage -- anyone with "x" already saved
    // would otherwise find their backend choice quietly reset to default.
    case dosboxX = "x"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .staging: return "dosbox-staging"
        case .dosboxX: return "dosbox-x"
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
            return ExecutableLocator.firstExecutable(in: Backend.stagingCandidates)
        case .dosboxX:
            return ExecutableLocator.firstExecutable(in: [Backend.xCandidate])
        }
    }

    var isInstalled: Bool { executablePath != nil }

    var installHint: String {
        switch self {
        case .staging: return "brew install dosbox-staging"
        case .dosboxX: return "brew install --cask dosbox-x-app"
        }
    }

    static var brewPath: String? {
        ExecutableLocator.firstExecutable(in: brewCandidates)
    }
}
