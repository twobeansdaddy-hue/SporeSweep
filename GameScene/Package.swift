// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GameScene",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "GameScene", targets: ["GameScene"])
    ],
    dependencies: [
        .package(path: "../GameCore")
    ],
    targets: [
        .target(
            name: "GameScene",
            dependencies: ["GameCore"],
            resources: [.process("Sounds"), .process("Sprites"), .process("Music")]
        ),
        .testTarget(name: "GameSceneTests", dependencies: ["GameScene", "GameCore"]),
    ]
)
