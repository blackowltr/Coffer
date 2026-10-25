// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "UnPack",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "UnPack",
            targets: ["UnPack"]
        )
    ],
    targets: [
        .executableTarget(
            name: "UnPack",
            path: "Sources",
            exclude: ["FinderSync/Info.plist"]
        )
    ]
)
