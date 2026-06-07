// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MusicApp",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "MusicApp", targets: ["MusicApp"])
    ],
    dependencies: [
        .package(path: "../CoreKit"),
        .package(path: "../MelodifyDesignSystem")
    ],
    targets: [
        .target(
            name: "MusicApp",
            dependencies: ["CoreKit", "MelodifyDesignSystem"],
            path: "Sources/MusicApp"
        )
    ]
)
