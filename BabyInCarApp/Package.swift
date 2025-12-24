// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "BabyInCarApp",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "BabyInCarApp",
            targets: ["BabyInCarApp"]),
    ],
    dependencies: [
        // No external dependencies - using only Apple frameworks
    ],
    targets: [
        .target(
            name: "BabyInCarApp",
            dependencies: [],
            path: "BabyInCarApp",
            resources: [
                .process("Assets.xcassets"),
                .process("LaunchScreen.storyboard")
            ]
        ),
        .testTarget(
            name: "BabyInCarAppTests",
            dependencies: ["BabyInCarApp"]),
    ]
)
