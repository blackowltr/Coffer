// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Coffer",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "Coffer",
            targets: ["Coffer"]
        )
    ],
    targets: [
        .executableTarget(
            name: "Coffer",
            path: "Sources"
        )
    ]
)
