// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LevelData",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "LevelData", targets: ["LevelData"])
    ],
    dependencies: [
        .package(path: "../GameCore")
    ],
    targets: [
        .target(
            name: "LevelData",
            dependencies: ["GameCore"],
            resources: [.process("Levels")]
        ),
        // 레벨을 만들고 재는 도구. 앱에는 들어가지 않는다.
        .target(name: "LevelTools", dependencies: ["LevelData", "GameCore"]),
        .executableTarget(name: "levelgen", dependencies: ["LevelTools", "LevelData"]),
        .executableTarget(name: "levelaudit", dependencies: ["LevelTools", "LevelData", "GameCore"]),
        .executableTarget(name: "leveldebug", dependencies: ["LevelTools", "LevelData", "GameCore"]),
        // 안드로이드 판이 규칙을 똑같이 따르는지 보는 기준 기록을 만든다.
        .executableTarget(name: "paritygen", dependencies: ["LevelData", "GameCore"]),
        .testTarget(name: "LevelDataTests", dependencies: ["LevelData", "LevelTools", "GameCore"]),
    ]
)
