// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "TransmuteIntelligence",
    platforms: [.iOS("27.0"), .watchOS("27.0"), .macOS("27.0")],
    products: [
        .library(name: "TransmuteIntelligence", targets: ["TransmuteIntelligence"])
    ],
    dependencies: [
        .package(path: "../TransmuteCore")
    ],
    targets: [
        .target(name: "TransmuteIntelligence", dependencies: ["TransmuteCore"]),
        .testTarget(name: "TransmuteIntelligenceTests", dependencies: ["TransmuteIntelligence"]),
    ]
)
