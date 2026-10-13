// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "ClipRecallCore",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "ClipRecallCore", targets: ["ClipRecallCore"])
    ],
    targets: [
        .target(name: "ClipRecallCore"),
        .testTarget(name: "ClipRecallCoreTests", dependencies: ["ClipRecallCore"])
    ]
)
