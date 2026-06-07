// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ChatApp",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "ChatApp", targets: ["ChatApp"])
    ],
    dependencies: [
        .package(path: "../CoreKit"),
        .package(path: "../MelodifyDesignSystem")
    ],
    targets: [
        .target(
            name: "ChatApp",
            dependencies: ["CoreKit", "MelodifyDesignSystem"],
            path: "Sources/ChatApp",
            resources: [
                .process("Data/MockData")
            ]
        )
    ]
)
