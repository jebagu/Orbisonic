import Foundation

enum ArchitectureBoundaryAllowlist {
    struct Pattern: Hashable {
        let id: String
        let expression: String
    }

    static let audioImplementationImports: [Pattern] = [
        Pattern(id: "importAVFAudio", expression: #"^\s*import\s+AVFAudio\b"#),
        Pattern(id: "importAVFoundation", expression: #"^\s*import\s+AVFoundation\b"#),
        Pattern(id: "importCoreAudio", expression: #"^\s*import\s+CoreAudio\b"#),
        Pattern(id: "importCoreAudioTypes", expression: #"^\s*import\s+CoreAudioTypes\b"#),
        Pattern(id: "importAudioToolbox", expression: #"^\s*import\s+AudioToolbox\b"#),
        Pattern(id: "importAudioUnit", expression: #"^\s*import\s+AudioUnit\b"#),
        Pattern(id: "importAccelerate", expression: #"^\s*import\s+Accelerate\b"#)
    ]

    static let uiImports: [Pattern] = [
        Pattern(id: "importSwiftUI", expression: #"^\s*import\s+SwiftUI\b"#),
        Pattern(id: "importAppKit", expression: #"^\s*import\s+AppKit\b"#),
        Pattern(id: "importCombine", expression: #"^\s*import\s+Combine\b"#)
    ]

    static let audioImplementationSymbols: [Pattern] = [
        Pattern(id: "AVAudioEngine", expression: #"\bAVAudioEngine\b"#),
        Pattern(id: "AVAudioNode", expression: #"\bAVAudioNode\b"#),
        Pattern(id: "AVAudioMixerNode", expression: #"\bAVAudioMixerNode\b"#),
        Pattern(id: "AVAudioPlayerNode", expression: #"\bAVAudioPlayerNode\b"#),
        Pattern(id: "AVAudioSourceNode", expression: #"\bAVAudioSourceNode\b"#),
        Pattern(id: "AVAudioEnvironmentNode", expression: #"\bAVAudioEnvironmentNode\b"#),
        Pattern(id: "AVAudioPCMBuffer", expression: #"\bAVAudioPCMBuffer\b"#),
        Pattern(id: "AVAudioFile", expression: #"\bAVAudioFile\b"#),
        Pattern(id: "AVAudioConverter", expression: #"\bAVAudioConverter\b"#),
        Pattern(id: "AudioUnit", expression: #"\bAudioUnit\b"#),
        Pattern(id: "AudioDeviceID", expression: #"\bAudioDeviceID\b"#),
        Pattern(id: "AudioBufferList", expression: #"\bAudioBufferList\b"#),
        Pattern(id: "UnsafeMutablePointer<Float>", expression: #"UnsafeMutablePointer\s*<\s*Float\s*>"#),
        Pattern(id: "UnsafeBufferPointer<Float>", expression: #"UnsafeBufferPointer\s*<\s*Float\s*>"#),
        Pattern(id: "RendererMatrix", expression: #"\bRendererMatrix\b"#),
        Pattern(id: "RingBuffer", expression: #"\b[A-Za-z0-9_]*RingBuffer[A-Za-z0-9_]*\b"#),
        Pattern(id: "LiveAudioPipe", expression: #"\bLiveAudioPipe[A-Za-z0-9_]*\b"#),
        Pattern(id: "installTap", expression: #"\binstallTap\s*\("#),
        Pattern(id: "connectCall", expression: #"\bconnect\s*\("#),
        Pattern(id: "disconnectCall", expression: #"\bdisconnect[A-Za-z0-9_]*\b"#),
        Pattern(id: "mainMixerNode", expression: #"\bmainMixerNode\b"#),
        Pattern(id: "outputNode", expression: #"\boutputNode\b"#)
    ]

    static let sharedPackageBackDependencyImports: [Pattern] = [
        Pattern(id: "importAudioImport", expression: #"^\s*import\s+AudioImport\b"#),
        Pattern(id: "importAudioCore", expression: #"^\s*import\s+AudioCore\b"#),
        Pattern(id: "importOrbisonic", expression: #"^\s*import\s+Orbisonic\b"#)
    ]

    static let appRuntimeSymbols: [Pattern] = [
        Pattern(id: "ContentView", expression: #"\bContentView\b"#),
        Pattern(id: "DiagnosticsView", expression: #"\bDiagnosticsView\b"#),
        Pattern(id: "InputSourceStatusPanel", expression: #"\bInputSourceStatusPanel[A-Za-z0-9_]*\b"#),
        Pattern(id: "OrbisonicApp", expression: #"\bOrbisonicApp\b"#),
        Pattern(id: "OrbisonicViewModel", expression: #"\bOrbisonicViewModel\b"#),
        Pattern(id: "OrbisonicEngine", expression: #"\bOrbisonicEngine\b"#),
        Pattern(id: "OrbisonicWebServer", expression: #"\bOrbisonicWebServer\b"#),
        Pattern(id: "LiveAudioBridge", expression: #"\bLiveAudioBridge\b"#),
        Pattern(id: "OutputRouteMonitor", expression: #"\bOutputRouteMonitor\b"#),
        Pattern(id: "BlackHoleRouteRepair", expression: #"\bBlackHoleRouteRepair\b"#),
        Pattern(id: "RoonNowPlayingReader", expression: #"\bRoonNowPlayingReader\b"#),
        Pattern(id: "RoonBridgeClient", expression: #"\bRoonBridgeClient\b"#),
        Pattern(id: "SpotifyReceiverClient", expression: #"\bSpotifyReceiverClient\b"#),
        Pattern(id: "AppLogger", expression: #"\bAppLogger\b"#),
        Pattern(id: "DiagnosticsLogStore", expression: #"\bDiagnosticsLogStore\b"#)
    ]

    static let filesystemImplementationSymbols: [Pattern] = [
        Pattern(id: "FileManager", expression: #"\bFileManager\b"#),
        Pattern(id: "fileURLWithPath", expression: #"\bURL\s*\(\s*fileURLWithPath\s*:"#),
        Pattern(id: "NSHomeDirectory", expression: #"\bNSHomeDirectory\s*\("#),
        Pattern(id: "UserDefaults", expression: #"\bUserDefaults\b"#)
    ]

    static let sourceIntegrationFiles: Set<String> = [
        "Sources/Orbisonic/RoonArtworkCache.swift",
        "Sources/Orbisonic/RoonBridgeClient.swift",
        "Sources/Orbisonic/RoonNowPlayingMonitor.swift",
        "Sources/Orbisonic/SpotifyReceiverClient.swift"
    ]

    static let sourceIntegrationRendererTopologySymbols: [Pattern] = [
        Pattern(id: "RendererModule", expression: #"\bRendererModule\b"#),
        Pattern(id: "RendererRenderMode", expression: #"\bRendererRenderMode\b"#),
        Pattern(id: "RendererMatrix", expression: #"\bRendererMatrix\b"#),
        Pattern(id: "RendererMatrixSampleRenderer", expression: #"\bRendererMatrixSampleRenderer\b"#),
        Pattern(id: "RenderGraphPlan", expression: #"\bRenderGraphPlan\b"#),
        Pattern(id: "RenderGraphPlanner", expression: #"\bRenderGraphPlanner\b"#),
        Pattern(id: "DanteSonicSphereRenderer", expression: #"\bDanteSonicSphereRenderer\b"#),
        Pattern(id: "direct30Layout", expression: #"\bAudioChannelLayoutDescriptor\s*\.\s*direct30\b"#),
        Pattern(id: "direct31Layout", expression: #"\bAudioChannelLayoutDescriptor\s*\.\s*direct31\b"#)
    ]

    static let monitorPathFiles: Set<String> = [
        "Sources/AudioCore/Monitors/AppleSpatialHeadphoneMonitor.swift",
        "Sources/Orbisonic/AudioSpatialUsageAudit.swift",
        "Sources/Orbisonic/NormalMonitorConversionLedger.swift",
        "Sources/Orbisonic/NormalMonitorGraphTopology.swift",
        "Sources/Orbisonic/NormalMonitorRouteDescriptor.swift",
        "Sources/Orbisonic/NormalMonitorStereoDownmixer.swift"
    ]

    static let monitorProductionTopologySymbols: [Pattern] = [
        Pattern(id: "RendererModule", expression: #"\bRendererModule\b"#),
        Pattern(id: "RendererMatrix", expression: #"\bRendererMatrix\b"#),
        Pattern(id: "RendererMatrixSampleRenderer", expression: #"\bRendererMatrixSampleRenderer\b"#),
        Pattern(id: "RenderGraphPlan", expression: #"\bRenderGraphPlan\b"#),
        Pattern(id: "RenderGraphPlanner", expression: #"\bRenderGraphPlanner\b"#),
        Pattern(id: "PureAudioDanteRendererPlan", expression: #"\bPureAudioDanteRendererPlan\b"#),
        Pattern(id: "DanteSonicSphereRenderer", expression: #"\bDanteSonicSphereRenderer\b"#),
        Pattern(id: "direct30Layout", expression: #"\bAudioChannelLayoutDescriptor\s*\.\s*direct30\b"#),
        Pattern(id: "direct31Layout", expression: #"\bAudioChannelLayoutDescriptor\s*\.\s*direct31\b"#)
    ]

    static let uiAndViewModelFiles: Set<String> = [
        "Sources/Orbisonic/ContentView.swift",
        "Sources/Orbisonic/DiagnosticsView.swift",
        "Sources/Orbisonic/InputSourceStatusPanelModel.swift",
        "Sources/Orbisonic/OrbisonicApp.swift",
        "Sources/Orbisonic/OrbisonicDisclosureTray.swift",
        "Sources/Orbisonic/OrbisonicViewModel.swift",
        "Sources/Orbisonic/OrbisonicWebServer.swift"
    ]

    static let vuDisplayFiles: Set<String> = [
        "Sources/Orbisonic/ContentView.swift",
        "Sources/Orbisonic/DiagnosticsView.swift",
        "Sources/Orbisonic/InputSourceStatusPanelModel.swift",
        "Sources/Orbisonic/OrbisonicWebServer.swift"
    ]

    static let audioImportCompatibilityFiles: Set<String> = [
        "Sources/AudioImport/LocalAssetImport.swift",
        "Sources/Orbisonic/AudioFileLoader.swift",
        "Sources/Orbisonic/AudioFileProbe.swift",
        "Sources/Orbisonic/LocalAudioFileSource.swift",
        "Sources/Orbisonic/LocalMusicLibrary.swift",
        "Sources/Orbisonic/MatroskaFLACSupport.swift",
        "Sources/Orbisonic/StreamingAudioFileSource.swift",
        "Sources/Orbisonic/SurroundSupport.swift",
        "Sources/Orbisonic/TestToneSupport.swift"
    ]

    static let legacyAudioCoreCompatibilityFiles: Set<String> = [
        "Sources/Orbisonic/BlackHoleRouteRepair.swift",
        "Sources/Orbisonic/LiveAudioBridge.swift",
        "Sources/Orbisonic/LocalGaplessScheduler.swift",
        "Sources/Orbisonic/LocalGaplessTypes.swift",
        "Sources/Orbisonic/MeteringService.swift",
        "Sources/Orbisonic/OrbisonicEngine.swift",
        "Sources/Orbisonic/OutputRouteMonitor.swift",
        "Sources/Orbisonic/RendererMatrixSampleRenderer.swift",
        "Sources/Orbisonic/RendererModule.swift"
    ]

    static let allowedForbiddenPatternIDsByFile: [String: Set<String>] = [
        "Sources/AudioImport/LocalAssetImport.swift": [
            "importAVFoundation", "AVAudioPCMBuffer", "AVAudioFile", "AVAudioConverter"
        ],
        "Sources/AudioCore/Monitors/AppleSpatialHeadphoneMonitor.swift": [
            "importAVFAudio", "AVAudioEnvironmentNode"
        ],
        "Sources/Orbisonic/AudioFileLoader.swift": [
            "importAVFoundation", "importCoreAudio", "importCoreAudioTypes",
            "AVAudioPCMBuffer", "AVAudioFile", "AVAudioConverter"
        ],
        "Sources/Orbisonic/AudioFileProbe.swift": [
            "importAVFoundation", "importCoreAudioTypes", "AVAudioFile"
        ],
        "Sources/Orbisonic/AudioSpatialUsageAudit.swift": [
            "AVAudioEnvironmentNode"
        ],
        "Sources/Orbisonic/BlackHoleRouteRepair.swift": [
            "importCoreAudio", "AudioDeviceID"
        ],
        "Sources/Orbisonic/CoreAudioDanteOutputSession.swift": [
            "importCoreAudio", "AudioDeviceID"
        ],
        "Sources/Orbisonic/LiveAudioBridge.swift": [
            "importAudioToolbox", "importAVFoundation", "AudioUnit", "AudioDeviceID",
            "AudioBufferList", "AVAudioPCMBuffer", "UnsafeMutablePointer<Float>",
            "RendererMatrix", "RingBuffer", "LiveAudioPipe"
        ],
        "Sources/Orbisonic/LocalAudioFileSource.swift": [
            "importAudioToolbox", "importAVFoundation", "AVAudioPCMBuffer", "AVAudioFile", "AVAudioConverter"
        ],
        "Sources/Orbisonic/LocalMusicLibrary.swift": [
            "importAVFoundation", "AVAudioFile"
        ],
        "Sources/Orbisonic/LocalGaplessTypes.swift": [
            "importAVFoundation", "AVAudioPCMBuffer"
        ],
        "Sources/Orbisonic/LocalGaplessScheduler.swift": [
            "importAVFoundation", "AVAudioPlayerNode", "AVAudioPCMBuffer"
        ],
        "Sources/Orbisonic/MeteringService.swift": [
            "importAVFoundation", "AVAudioPCMBuffer", "AudioBufferList"
        ],
        "Sources/Orbisonic/NormalMonitorConversionLedger.swift": [
            "AVAudioEngine"
        ],
        "Sources/Orbisonic/NormalMonitorGraphTopology.swift": [
            "mainMixerNode"
        ],
        "Sources/Orbisonic/NormalMonitorRouteDescriptor.swift": [
            "AVAudioEnvironmentNode"
        ],
        "Sources/Orbisonic/OrbisonicEngine.swift": [
            "importAudioToolbox", "importAVFoundation", "AVAudioEngine", "AVAudioMixerNode",
            "AVAudioPlayerNode", "AVAudioSourceNode", "AVAudioPCMBuffer", "AVAudioFile", "AudioUnit",
            "AudioDeviceID", "AudioBufferList", "UnsafeMutablePointer<Float>", "RendererMatrix",
            "LiveAudioPipe", "installTap", "connectCall", "disconnectCall", "mainMixerNode",
            "outputNode"
        ],
        "Sources/Orbisonic/OrbisonicViewModel.swift": [
            "importAVFoundation", "LiveAudioPipe"
        ],
        "Sources/Orbisonic/OutputRouteMonitor.swift": [
            "importCoreAudio", "AudioDeviceID", "AudioBufferList"
        ],
        "Sources/Orbisonic/RendererMatrixSampleRenderer.swift": [
            "importAVFoundation", "AVAudioPCMBuffer", "AudioBufferList", "RendererMatrix"
        ],
        "Sources/Orbisonic/RendererModule.swift": [
            "RendererMatrix"
        ],
        "Sources/Orbisonic/StreamingAudioFileSource.swift": [
            "importAVFoundation", "AVAudioPCMBuffer", "AVAudioFile", "AVAudioConverter",
            "AudioBufferList"
        ],
        "Sources/Orbisonic/SurroundSupport.swift": [
            "importAVFoundation", "importCoreAudio", "importCoreAudioTypes", "AVAudioFile"
        ],
        "Sources/Orbisonic/TestToneSupport.swift": [
            "importAVFoundation", "AVAudioPCMBuffer", "AVAudioFile"
        ]
    ]

    static let uiImportExceptionsByFile: [String: Set<String>] = [
        "Sources/Orbisonic/OrbisonicEngine.swift": ["importAppKit"]
    ]

    static let migrationExceptionNotes: [String: String] = [
        "Sources/Orbisonic/OrbisonicEngine.swift":
            "Legacy graph owner until AudioCore replaces AVAudioEngine mutation.",
        "Sources/Orbisonic/OrbisonicViewModel.swift":
            "Legacy view model still imports AVFoundation for audio permission and observes legacy pipe status.",
        "Sources/Orbisonic/MeteringService.swift":
            "Legacy metering still reads PCM buffers; final VU display must consume MeterSnapshot values only.",
        "Sources/Orbisonic/RendererModule.swift":
            "Legacy renderer matrix model is analysis/metering-only until AudioCore owns production render plans.",
        "Sources/Orbisonic/RendererMatrixSampleRenderer.swift":
            "Legacy meter-only Sonic Sphere projection helper.",
        "Sources/Orbisonic/OutputRouteMonitor.swift":
            "Legacy Core Audio route discovery until AudioCore route adapters exist.",
        "Sources/Orbisonic/BlackHoleRouteRepair.swift":
            "Legacy Core Audio route repair until route mutation is moved behind AudioCore.",
        "Sources/Orbisonic/CoreAudioDanteOutputSession.swift":
            "Task 012 DVS/CoreAudio route-fact query boundary behind ProductionOutputSession.",
        "Sources/AudioCore/Monitors/AppleSpatialHeadphoneMonitor.swift":
            "AudioCore-owned desktop monitor implementation; UI receives only value status and commands."
    ]
}
