import Foundation

/// Detection for `unshield`, used to unpack InstallShield-packaged DATA1.CAB
/// archives without running the (Windows) installer itself. Unlike
/// Battlespire's raw disc, Redguard's retail installer is a real
/// InstallShield package -- `cabextract` can't read its proprietary CAB
/// variant, `unshield` can. See REDGUARD.md.
enum UnshieldTool {
    static let candidates = [
        "/opt/homebrew/bin/unshield",
        "/usr/local/bin/unshield",
    ]

    static var executablePath: String? {
        ExecutableLocator.firstExecutable(in: candidates)
    }

    static var isInstalled: Bool { executablePath != nil }
}
