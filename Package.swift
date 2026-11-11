// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BorderMark",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "BorderMarkCore", targets: ["BorderMarkCore"]),
        .executable(name: "BorderMark", targets: ["BorderMarkApp"]),
        .executable(name: "bordermark-cli", targets: ["BorderMarkCLI"]),
    ],
    targets: [
        .target(name: "BorderMarkCore", resources: [.copy("Resources/Logos")]),
        .executableTarget(name: "BorderMarkApp", dependencies: ["BorderMarkCore"]),
        .executableTarget(name: "BorderMarkCLI", dependencies: ["BorderMarkCore"]),
        .testTarget(name: "BorderMarkCoreTests", dependencies: ["BorderMarkCore"]),
    ]
)
