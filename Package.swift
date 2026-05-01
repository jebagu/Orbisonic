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
        ),
        .library(
            name: "AudioContracts",
            targets: ["AudioContracts"]
        ),
        .library(
            name: "AudioImport",
            targets: ["AudioImport"]
        ),
        .library(
            name: "AudioCore",
            targets: ["AudioCore"]
        )
    ],
    targets: [
        .target(
            name: "AudioContracts"
        ),
        .target(
            name: "AudioImport",
            dependencies: ["AudioContracts"]
        ),
        .target(
            name: "AudioCore",
            dependencies: ["AudioContracts", "AudioImport"]
        ),
        .executableTarget(
            name: "Orbisonic",
            dependencies: ["AudioContracts", "AudioImport", "AudioCore"],
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
        ),
        .testTarget(
            name: "AudioImportTests",
            dependencies: ["AudioImport", "AudioContracts"]
        ),
        .testTarget(
            name: "AudioCoreTests",
            dependencies: ["AudioCore", "AudioContracts", "AudioImport"]
        )
    ]
)
