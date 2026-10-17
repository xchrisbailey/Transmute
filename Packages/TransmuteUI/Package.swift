// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "TransmuteUI",
    platforms: [.iOS("27.0"), .watchOS("27.0"), .macOS("27.0")],
    products: [
        .library(name: "TransmuteUI", targets: ["TransmuteUI"]),
        .library(name: "TransmutePlanUI", targets: ["TransmutePlanUI"]),
        .library(name: "TransmuteLogUI", targets: ["TransmuteLogUI"]),
        .library(name: "TransmuteSettingsUI", targets: ["TransmuteSettingsUI"]),
    ],
    dependencies: [
        .package(path: "../TransmuteCore"),
        .package(path: "../TransmuteIntelligence"),
    ],
    targets: [
        .target(name: "TransmuteUI", dependencies: ["TransmuteCore"]),
        .target(
            name: "TransmutePlanUI",
            dependencies: ["TransmuteUI", "TransmuteCore", "TransmuteIntelligence"]),
        .target(
            name: "TransmuteLogUI",
            dependencies: ["TransmuteUI", "TransmutePlanUI", "TransmuteCore", "TransmuteIntelligence"]),
        .target(
            name: "TransmuteSettingsUI",
            dependencies: [
                "TransmuteUI", "TransmutePlanUI", "TransmuteLogUI", "TransmuteCore", "TransmuteIntelligence",
            ]),
        .testTarget(
            name: "TransmuteUITests",
            dependencies: ["TransmuteUI", .product(name: "TransmuteTestSupport", package: "TransmuteCore")]),
        .testTarget(
            name: "TransmutePlanUITests",
            dependencies: ["TransmutePlanUI", .product(name: "TransmuteTestSupport", package: "TransmuteCore")]),
        .testTarget(
            name: "TransmuteLogUITests",
            dependencies: ["TransmuteLogUI", .product(name: "TransmuteTestSupport", package: "TransmuteCore")]),
        .testTarget(
            name: "TransmuteSettingsUITests",
            dependencies: ["TransmuteSettingsUI", .product(name: "TransmuteTestSupport", package: "TransmuteCore")]),
    ]
)
