// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Doto",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "doto",
            targets: ["Doto"]
        ),
        .library(
            name: "DotoCore",
            targets: ["DotoCore"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "DotoCore",
            dependencies: [],
            path: "Sources/DotoCore",
            resources: [
                .process("Shaders")
            ]
        ),
        .executableTarget(
            name: "Doto",
            dependencies: ["DotoCore"],
            path: "Sources/Doto"
        ),
        .testTarget(
            name: "DotoTests",
            dependencies: ["DotoCore"],
            path: "Tests/DotoTests"
        )
    ]
)
