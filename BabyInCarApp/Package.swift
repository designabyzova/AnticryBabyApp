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
        // Testing Dependencies
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing.git", from: "1.15.0"),
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
            dependencies: [
                "BabyInCarApp",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ],
            resources: [
                .copy("Fixtures")
            ]
        ),
    ]
)
