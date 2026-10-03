// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "TransmuteUI",
    platforms: [.iOS("27.0"), .watchOS("27.0"), .macOS("27.0")],
    products: [
        .library(name: "TransmuteUI", targets: ["TransmuteUI"]),
        // Screens that brew and edit plans. iPhone and Mac only: the watch never generates.
        .library(name: "TransmutePlanUI", targets: ["TransmutePlanUI"]),
        // Today, the workout session and history. iPhone and Mac; the watch has its own (#15).
        .library(name: "TransmuteLogUI", targets: ["TransmuteLogUI"]),
        // The Settings screen (#18). iPhone and Mac; it reaches into every other target.
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
        .testTarget(name: "TransmuteUITests", dependencies: ["TransmuteUI"]),
        .testTarget(name: "TransmutePlanUITests", dependencies: ["TransmutePlanUI"]),
        .testTarget(name: "TransmuteLogUITests", dependencies: ["TransmuteLogUI"]),
        .testTarget(name: "TransmuteSettingsUITests", dependencies: ["TransmuteSettingsUI"]),
    ]
)
