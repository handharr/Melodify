// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HotelBookingApp",
    platforms: [.iOS(.v16)],
    products: [.library(name: "HotelBookingApp", targets: ["HotelBookingApp"])],
    dependencies: [
        .package(path: "../CoreKit"),
        .package(path: "../MelodifyDesignSystem"),
    ],
    targets: [
        .target(
            name: "HotelBookingApp",
            dependencies: ["CoreKit", "MelodifyDesignSystem"],
            path: "Sources/HotelBookingApp"
        )
    ]
)
