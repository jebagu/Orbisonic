// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Orbisonic",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "Orbisonic",
            targets: ["Orbisonic"]
        )
    ],
    targets: [
        .executableTarget(
            name: "Orbisonic",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "OrbisonicTests",
            dependencies: ["Orbisonic"]
        )
    ]
)
