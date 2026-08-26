// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BattlespireLauncher",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(
            name: "BattlespireLauncher",
            path: "Sources/BattlespireLauncher",
            resources: [
                .copy("Battlespire/Resources/SPIRE.CFG"),
                .copy("Battlespire/Resources/DIG.INI"),
                .copy("Redguard/Resources/REDGUARD_DIG.INI"),
                .copy("Redguard/Resources/REDGUARD_MDI.INI"),
            ]
        ),
        .testTarget(
            name: "BattlespireLauncherTests",
            dependencies: ["BattlespireLauncher"],
            path: "Tests/BattlespireLauncherTests"
        ),
    ]
)
