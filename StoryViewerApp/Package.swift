// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "StoryViewerApp",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "StoryViewerApp", targets: ["StoryViewerApp"])
    ],
    dependencies: [
        .package(path: "../CoreKit")
    ],
    targets: [
        .target(
            name: "StoryViewerApp",
            dependencies: ["CoreKit"],
            path: "Sources/StoryViewerApp",
            resources: [
                .process("Data/MockData")
            ]
        )
    ]
)
