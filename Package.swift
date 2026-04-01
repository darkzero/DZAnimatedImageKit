// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "DZAnimatedImageKit",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "DZAnimatedImageKit",
            targets: ["DZAnimatedImageKit"]
        )
    ],
    targets: [
        .target(
            name: "DZAnimatedImageKit",
            path: "DZAnimatedImageKit/Sources"
        ),
        .testTarget(
            name: "DZAnimatedImageKitTests",
            dependencies: ["DZAnimatedImageKit"],
            path: "DZAnimatedImageKit/Tests"
        )
    ]
)
