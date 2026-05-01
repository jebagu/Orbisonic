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
        .target(
            name: "AudioContracts"
        ),
        .executableTarget(
            name: "Orbisonic",
            exclude: [
                "Resources/AppLogos/README.md"
            ],
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .define("ORBISONIC_ENABLE_EMBEDDED_LIBRESPOT")
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-L", ".build/orbisonic-librespot",
                    "-lorbisonic_librespot_ffi",
                    "-framework", "AudioToolbox",
                    "-framework", "CoreAudio",
                    "-framework", "CoreFoundation",
                    "-framework", "Foundation",
                    "-framework", "Security",
                    "-framework", "SystemConfiguration"
                ])
            ]
        ),
        .testTarget(
            name: "OrbisonicTests",
            dependencies: ["Orbisonic"]
        ),
        .testTarget(
            name: "AudioContractsTests",
            dependencies: ["AudioContracts"]
        )
    ]
)
