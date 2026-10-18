// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "NotchApp",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(name: "NotchApp", dependencies: ["NotchCore"]),
        .target(name: "NotchCore"),
        .testTarget(name: "NotchCoreTests", dependencies: ["NotchCore"]),
    ]
)
