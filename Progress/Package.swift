// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Progress",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "Progress", targets: ["Progress"])
    ],
    targets: [
        .target(name: "Progress"),
        .testTarget(name: "ProgressTests", dependencies: ["Progress"]),
    ]
)
