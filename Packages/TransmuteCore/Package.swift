// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "TransmuteCore",
    platforms: [.iOS("27.0"), .watchOS("27.0"), .macOS("27.0")],
    products: [
        .library(name: "TransmuteCore", targets: ["TransmuteCore"])
    ],
    targets: [
        .target(name: "TransmuteCore"),
        .testTarget(name: "TransmuteCoreTests", dependencies: ["TransmuteCore"]),
    ]
)
