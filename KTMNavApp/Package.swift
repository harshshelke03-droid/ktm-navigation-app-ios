// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "KTMNav",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "KTMNav",
            targets: ["KTMNav"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "KTMNav",
            dependencies: [],
            path: "KTMNav"
        ),
        .testTarget(
            name: "KTMNavTests",
            dependencies: ["KTMNav"],
            path: "Tests"
        ),
    ]
)
