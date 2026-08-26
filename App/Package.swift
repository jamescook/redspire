// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BattlespireLauncher",
    platforms: [.macOS(.v15)],
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
