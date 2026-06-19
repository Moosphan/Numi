// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "Numi",
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
            exclude: ["README.md"]
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
            resources: [
                .process("Assets/ThiingsIcons.xcassets")
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
        )
    ]
)
