// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "video_frames",
    platforms: [
        .iOS("15.0"),
        .macOS("14.0"),
    ],
    products: [
        .library(name: "video-frames", targets: ["video_frames"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "video_frames",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ]
        )
    ]
)
