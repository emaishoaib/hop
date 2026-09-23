// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "WindowSwitcher",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "WindowSwitcher"),
    ]
)
