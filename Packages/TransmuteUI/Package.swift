// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "TransmuteUI",
    platforms: [.iOS("27.0"), .watchOS("27.0"), .macOS("27.0")],
    products: [
        .library(name: "TransmuteUI", targets: ["TransmuteUI"])
    ],
    dependencies: [
        .package(path: "../TransmuteCore")
    ],
    targets: [
        .target(name: "TransmuteUI", dependencies: ["TransmuteCore"]),
        .testTarget(name: "TransmuteUITests", dependencies: ["TransmuteUI"]),
    ]
)
