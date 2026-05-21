// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MelodifyDesignSystem",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "MelodifyDesignSystem",
            targets: ["MelodifyDesignSystem"]
        )
    ],
    targets: [
        .target(
            name: "MelodifyDesignSystem"
        ),
        .testTarget(
            name: "MelodifyDesignSystemTests",
            dependencies: ["MelodifyDesignSystem"]
        )
    ]
)
