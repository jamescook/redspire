// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Redspire",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(
            name: "Redspire",
            path: "Sources/BattlespireLauncher",
            resources: [
                .copy("Battlespire/Resources/SPIRE.CFG"),
                .copy("Battlespire/Resources/DIG.INI"),
                .copy("Battlespire/Resources/battlespire.conf"),
                .copy("Redguard/Resources/REDGUARD_DIG.INI"),
                .copy("Redguard/Resources/REDGUARD_MDI.INI"),
                .copy("Redguard/Resources/redguard.conf"),
                .copy("Shared/Resources/Icons/battlespire-sword.svg"),
                .copy("Shared/Resources/Icons/redguard-scimitar.svg"),
                .copy("Shared/Resources/Icons/steam-logo.svg"),
                .copy("Shared/Resources/Icons/gog-logo.png"),
                .copy("Shared/Resources/AppIcon.icns"),
            ]
        ),
        .testTarget(
            name: "RedspireTests",
            dependencies: ["Redspire"],
            path: "Tests/BattlespireLauncherTests"
        ),
    ]
)
