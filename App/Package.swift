// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "BattlespireLauncher",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "BattlespireLauncher",
            path: "Sources/BattlespireLauncher"
        ),
        .testTarget(
            name: "BattlespireLauncherTests",
            dependencies: ["BattlespireLauncher"],
            path: "Tests/BattlespireLauncherTests"
        ),
    ]
)
