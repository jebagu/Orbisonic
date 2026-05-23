import AudioContracts
import Foundation

enum OrbitalVUMeterSource: Equatable, Hashable, Sendable {
    case input
    case desktopOutput
    case sonicSphereAnalysis
    case danteOutput

    var label: String {
        switch self {
        case .input:
            "Input Meter"
        case .desktopOutput:
            "Desktop Output Meter"
        case .sonicSphereAnalysis:
            "Sonic Sphere Analysis Meter"
        case .danteOutput:
            "Dante Output Meter"
        }
    }

    var isActualAudibleOutput: Bool {
        switch self {
        case .desktopOutput, .danteOutput:
            true
        case .input, .sonicSphereAnalysis:
            false
        }
    }

    var canMapToSonicSphereOutputMarkers: Bool {
        switch self {
        case .sonicSphereAnalysis, .danteOutput:
            true
        case .input, .desktopOutput:
            false
        }
    }

    static func sonicSphere(isActualDanteRenderBus: Bool) -> OrbitalVUMeterSource {
        isActualDanteRenderBus ? .danteOutput : .sonicSphereAnalysis
    }
}

struct OrbitalVUMeterChannelSnapshot: Equatable, Hashable, Sendable {
    var normalizedLevel: Float
    var peakDbFS: Float
    var isClipping: Bool

    init(normalizedLevel: Float, peakDbFS: Float, isClipping: Bool? = nil) {
        self.normalizedLevel = min(max(normalizedLevel, 0), 1)
        self.peakDbFS = peakDbFS
        self.isClipping = isClipping ?? (peakDbFS >= 0)
    }

    init(_ level: MeterChannelLevel) {
        self.init(
            normalizedLevel: level.displayLevel,
            peakDbFS: level.peakDbFS,
            isClipping: level.peakDbFS >= 0
        )
    }

    init(_ meter: AudioContracts.ChannelMeter) {
        self.init(
            normalizedLevel: meter.normalizedLevel,
            peakDbFS: meter.peakDBFS,
            isClipping: meter.isClipped
        )
    }

    static let silence = OrbitalVUMeterChannelSnapshot(
        normalizedLevel: 0,
        peakDbFS: MeterChannelLevel.silenceDbFS,
        isClipping: false
    )
}

struct OrbitalVUMeterSnapshot: Equatable, Sendable {
    var source: OrbitalVUMeterSource
    var channels: [OrbitalVUMeterChannelSnapshot]
    var isActive: Bool

    init(
        source: OrbitalVUMeterSource,
        channels: [OrbitalVUMeterChannelSnapshot],
        isActive: Bool? = nil
    ) {
        self.source = source
        self.channels = channels
        self.isActive = isActive ?? channels.contains { $0.normalizedLevel > 0 || $0.peakDbFS > MeterChannelLevel.activePeakFloorDbFS }
    }

    init(source: OrbitalVUMeterSource, meterLevels: [MeterChannelLevel], isActive: Bool) {
        self.init(
            source: source,
            channels: meterLevels.map(OrbitalVUMeterChannelSnapshot.init),
            isActive: isActive
        )
    }

    init(source: OrbitalVUMeterSource, contractMeters: [AudioContracts.ChannelMeter]) {
        self.init(
            source: source,
            channels: contractMeters.map(OrbitalVUMeterChannelSnapshot.init)
        )
    }

    static func input(from snapshot: AudioContracts.MeterSnapshot) -> OrbitalVUMeterSnapshot {
        OrbitalVUMeterSnapshot(source: .input, contractMeters: snapshot.inputMeters)
    }

    static func desktopOutput(from snapshot: AudioContracts.MeterSnapshot) -> OrbitalVUMeterSnapshot {
        OrbitalVUMeterSnapshot(source: .desktopOutput, contractMeters: snapshot.desktopMeters)
    }

    static func danteOutput(from snapshot: AudioContracts.MeterSnapshot) -> OrbitalVUMeterSnapshot {
        OrbitalVUMeterSnapshot(source: .danteOutput, contractMeters: snapshot.danteMeters)
    }
}

enum OrbitalVUMeterMarkerRole: String, Equatable, Hashable, Sendable {
    case sonicSphereFullRange
    case sonicSphereLFE
    case monitor
    case reservedPhysicalOutput
}

struct OrbitalVUMeterMarker: Identifiable, Equatable, Hashable, Sendable {
    var channelID: String
    var label: String
    var role: OrbitalVUMeterMarkerRole
    var normalizedLevel: Float
    var isClipping: Bool
    var isHot: Bool
    var meterSourceLabel: String
    var isActualAudibleOutput: Bool
    var isActive: Bool

    var id: String { channelID }
}

struct OrbitalVUMeterViewState: Equatable, Sendable {
    var meterSourceLabel: String
    var isActualAudibleOutput: Bool
    var markers: [OrbitalVUMeterMarker]

    var hasActiveMarkers: Bool {
        markers.contains { $0.isActive }
    }

    static func empty(source: OrbitalVUMeterSource) -> OrbitalVUMeterViewState {
        OrbitalVUMeterViewState(
            meterSourceLabel: source.label,
            isActualAudibleOutput: source.isActualAudibleOutput,
            markers: []
        )
    }
}

enum OrbitalVUMeterModel {
    static let hotNormalizedLevelThreshold: Float = 0.85
    static let hotPeakThresholdDbFS: Float = -3

    static func sonicSphereOutputState(
        scene: RendererSceneModel,
        meterSnapshot: OrbitalVUMeterSnapshot,
        physicalOutputChannelCount: Int? = nil
    ) -> OrbitalVUMeterViewState {
        guard meterSnapshot.source.canMapToSonicSphereOutputMarkers else {
            return .empty(source: meterSnapshot.source)
        }

        var markers = scene.outputSpeakers.map { speaker in
            marker(
                channelID: speaker.id,
                label: speaker.shortLabel,
                role: speaker.isLFE ? .sonicSphereLFE : .sonicSphereFullRange,
                meterIndex: speaker.index,
                meterSnapshot: meterSnapshot
            )
        }

        let physicalCount = max(physicalOutputChannelCount ?? markers.count, markers.count)
        if physicalCount > markers.count {
            for outputIndex in markers.count..<physicalCount {
                markers.append(
                    reservedMarker(
                        outputIndex: outputIndex,
                        source: meterSnapshot.source
                    )
                )
            }
        }

        return OrbitalVUMeterViewState(
            meterSourceLabel: meterSnapshot.source.label,
            isActualAudibleOutput: meterSnapshot.source.isActualAudibleOutput,
            markers: markers
        )
    }

    static func monitorState(
        channels: [SurroundChannel],
        meterSnapshot: OrbitalVUMeterSnapshot
    ) -> OrbitalVUMeterViewState {
        let markers = channels.map { channel in
            marker(
                channelID: "monitor-\(channel.id)",
                label: channelLabel(for: channel),
                role: .monitor,
                meterIndex: channel.index,
                meterSnapshot: meterSnapshot
            )
        }

        return OrbitalVUMeterViewState(
            meterSourceLabel: meterSnapshot.source.label,
            isActualAudibleOutput: meterSnapshot.source.isActualAudibleOutput,
            markers: markers
        )
    }

    private static func marker(
        channelID: String,
        label: String,
        role: OrbitalVUMeterMarkerRole,
        meterIndex: Int,
        meterSnapshot: OrbitalVUMeterSnapshot
    ) -> OrbitalVUMeterMarker {
        let channel = meterIndex >= 0 && meterIndex < meterSnapshot.channels.count
            ? meterSnapshot.channels[meterIndex]
            : .silence
        let normalizedLevel = meterSnapshot.isActive ? channel.normalizedLevel : 0
        let isClipping = meterSnapshot.isActive && channel.isClipping
        let isHot = meterSnapshot.isActive && (
            isClipping
                || channel.peakDbFS >= hotPeakThresholdDbFS
                || normalizedLevel >= hotNormalizedLevelThreshold
        )
        let isActive = meterSnapshot.isActive && (
            normalizedLevel > 0
                || channel.peakDbFS > MeterChannelLevel.activePeakFloorDbFS
                || isHot
        )

        return OrbitalVUMeterMarker(
            channelID: channelID,
            label: label,
            role: role,
            normalizedLevel: isActive ? normalizedLevel : 0,
            isClipping: isClipping,
            isHot: isHot,
            meterSourceLabel: meterSnapshot.source.label,
            isActualAudibleOutput: meterSnapshot.source.isActualAudibleOutput,
            isActive: isActive
        )
    }

    private static func reservedMarker(
        outputIndex: Int,
        source: OrbitalVUMeterSource
    ) -> OrbitalVUMeterMarker {
        OrbitalVUMeterMarker(
            channelID: "reserved-output-\(outputIndex + 1)",
            label: "\(outputIndex + 1)",
            role: .reservedPhysicalOutput,
            normalizedLevel: 0,
            isClipping: false,
            isHot: false,
            meterSourceLabel: source.label,
            isActualAudibleOutput: source.isActualAudibleOutput,
            isActive: false
        )
    }

    private static func channelLabel(for channel: SurroundChannel) -> String {
        switch channel.role {
        case .frontLeft:
            "L"
        case .frontRight:
            "R"
        case .center:
            "C"
        case .lfe:
            "LFE"
        case .lfe2:
            "LFE2"
        case .sideLeft:
            "Ls"
        case .sideRight:
            "Rs"
        case .rearLeft:
            "Lb"
        case .rearRight:
            "Rb"
        case .rearCenter:
            "Cb"
        case .wideLeft:
            "Lw"
        case .wideRight:
            "Rw"
        case .frontLeftCenter:
            "Lc"
        case .frontRightCenter:
            "Rc"
        case .topFrontLeft:
            "TFL"
        case .topFrontCenter:
            "TFC"
        case .topFrontRight:
            "TFR"
        case .topMiddleLeft:
            "TML"
        case .topMiddleCenter:
            "TMC"
        case .topMiddleRight:
            "TMR"
        case .topRearLeft:
            "TRL"
        case .topRearCenter:
            "TRC"
        case .topRearRight:
            "TRR"
        case .discrete(let index):
            "\(index + 1)"
        }
    }
}
