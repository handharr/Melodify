// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "UberEatsApp",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "UberEatsApp", targets: ["UberEatsApp"])
    ],
    dependencies: [
        .package(path: "../CoreKit"),
        .package(path: "../MelodifyDesignSystem")
    ],
    targets: [
        .target(
            name: "UberEatsApp",
            dependencies: ["CoreKit", "MelodifyDesignSystem"],
            path: "Sources/UberEatsApp"
        )
    ]
)
