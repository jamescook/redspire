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
            ]
        ),
        .testTarget(
            name: "RedspireTests",
            dependencies: ["Redspire"],
            path: "Tests/BattlespireLauncherTests"
        ),
    ]
)
