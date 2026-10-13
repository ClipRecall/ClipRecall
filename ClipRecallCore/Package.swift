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
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0")
    ],
    targets: [
        .target(
            name: "ClipRecallCore",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift")
            ]
        ),
        .testTarget(name: "ClipRecallCoreTests", dependencies: ["ClipRecallCore"])
    ]
)
