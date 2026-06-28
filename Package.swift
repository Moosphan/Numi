// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "Numi",
    defaultLocalization: "zh-Hans",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "NumiCore", targets: ["NumiCore"]),
        .library(name: "NumiPersistence", targets: ["NumiPersistence"]),
        .library(name: "NumiAppUI", targets: ["NumiAppUI"])
    ],
    targets: [
        .target(
            name: "NumiCore",
            path: "Sources/NumiCore",
            exclude: ["README.md"],
            resources: [
                .process("Localizable.xcstrings")
            ]
        ),
        .target(
            name: "NumiPersistence",
            dependencies: ["NumiCore"],
            path: "Sources/NumiPersistence"
        ),
        .target(
            name: "NumiAppUI",
            dependencies: ["NumiCore"],
            path: "Sources/NumiAppUI",
            exclude: ["Assets/ThiingsIcons/README.md"],
            resources: [
                .process("Assets/ThiingsIcons.xcassets"),
                .copy("Assets/ThiingsIcons/Icons"),
                .copy("Assets/ThiingsIcons/manifest.json"),
                .process("Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "NumiCoreTests",
            dependencies: ["NumiCore"],
            path: "Tests/NumiCoreTests"
        ),
        .testTarget(
            name: "NumiPersistenceTests",
            dependencies: ["NumiCore", "NumiPersistence"],
            path: "Tests/NumiPersistenceTests"
        ),
        .testTarget(
            name: "NumiAppUITests",
            dependencies: ["NumiAppUI"],
            path: "Tests/NumiAppUITests",
            exclude: ["RootShellStoreRecoveryTests.swift"]
        )
    ]
)
