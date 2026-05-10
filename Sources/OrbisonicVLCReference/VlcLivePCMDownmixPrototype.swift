import AudioContracts
import Foundation

struct VlcLivePCMInputBlock: Equatable, Sendable {
    let sourceID: String
    let sourceKind: SourceKind
    let generation: UInt64
    let sampleRate: AudioSampleRate
    let channelCount: Int
    let frameStart: Int64
    let frameCount: Int
    let layout: AudioChannelLayoutDescriptor
    let planarSamples: [[Float]]

    init(
        sourceID: String,
        sourceKind: SourceKind,
        generation: UInt64,
        sampleRate: AudioSampleRate,
        channelCount: Int,
        frameStart: Int64,
        frameCount: Int,
        layout: AudioChannelLayoutDescriptor,
        planarSamples: [[Float]]
    ) throws {
        guard channelCount > 0 else {
            throw VlcLivePCMDownmixPrototypeError.unsupportedChannelCount(channelCount)
        }
        guard frameCount > 0 else {
            throw VlcLivePCMDownmixPrototypeError.invalidFrameCount(frameCount)
        }
        guard planarSamples.count == channelCount else {
            throw VlcLivePCMDownmixPrototypeError.sampleChannelCountMismatch(
                expected: channelCount,
                actual: planarSamples.count
            )
        }
        for (channel, samples) in planarSamples.enumerated() where samples.count != frameCount {
            throw VlcLivePCMDownmixPrototypeError.sampleFrameCountMismatch(
                channel: channel,
                expected: frameCount,
                actual: samples.count
            )
        }

        self.sourceID = sourceID
        self.sourceKind = sourceKind
        self.generation = generation
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        self.frameStart = frameStart
        self.frameCount = frameCount
        self.layout = layout
        self.planarSamples = planarSamples
    }

    func sample(channel: Int, frame: Int) -> Float {
        guard channel >= 0,
              channel < channelCount,
              frame >= 0,
              frame < frameCount
        else { return 0 }
        return planarSamples[channel][frame]
    }
}

struct VlcReadableRawPCMStream: Equatable, Sendable {
    let formatFourCC: String
    let sampleRate: AudioSampleRate
    let channelCount: Int
    let frameStart: Int64
    let frameCount: Int
    let interleavedSamples: [Float]
}

struct VlcLivePCMDownmixMeasurements: Equatable, Sendable {
    let inputFrameCount: Int
    let outputFrameCount: Int
    let latencyFrames: Int
    let latencyMilliseconds: Double
    let driftFrames: Int
    let driftPartsPerMillion: Double
}

struct VlcLivePCMDownmixPrototypeResult: Equatable, Sendable {
    let rawStream: VlcReadableRawPCMStream
    let callback: VlcStereoMonitorCallbackBuffer
    let downmixOwner: AudioConversionOwner
    let measurements: VlcLivePCMDownmixMeasurements
    let ledger: AudioConversionLedger
}

enum VlcLivePCMDownmixSelection: Equatable, Hashable, Sendable {
    case disabled
    case selectedForRoonMonitor
}

enum VlcLivePCMDownmixPrototypeError: Error, Equatable {
    case notSelected
    case unsupportedSourceKind(SourceKind)
    case unsupportedChannelCount(Int)
    case unsupportedLayout(String)
    case invalidFrameCount(Int)
    case sampleChannelCountMismatch(expected: Int, actual: Int)
    case sampleFrameCountMismatch(channel: Int, expected: Int, actual: Int)
}

struct VlcLivePCMDownmixPrototype: Sendable {
    static let downmixOwner = AudioConversionOwner.external("VLC live PCM bridge")

    let selection: VlcLivePCMDownmixSelection
    let simulatedProcessingLatencyFrames: Int

    init(
        selection: VlcLivePCMDownmixSelection = .disabled,
        simulatedProcessingLatencyFrames: Int = 48
    ) {
        self.selection = selection
        self.simulatedProcessingLatencyFrames = max(simulatedProcessingLatencyFrames, 0)
    }

    func feedCapturedPCM(_ input: VlcLivePCMInputBlock) throws -> VlcLivePCMDownmixPrototypeResult {
        guard selection == .selectedForRoonMonitor else {
            throw VlcLivePCMDownmixPrototypeError.notSelected
        }
        guard input.sourceKind == .roon else {
            throw VlcLivePCMDownmixPrototypeError.unsupportedSourceKind(input.sourceKind)
        }
        guard input.channelCount == 6 else {
            throw VlcLivePCMDownmixPrototypeError.unsupportedChannelCount(input.channelCount)
        }
        guard input.layout == .surround51 else {
            throw VlcLivePCMDownmixPrototypeError.unsupportedLayout(input.layout.name)
        }

        let rawStream = makeRawStream(from: input)
        let callback = VlcStereoMonitorCallbackBuffer(
            generation: input.generation,
            frameStart: input.frameStart + Int64(simulatedProcessingLatencyFrames),
            frameCount: input.frameCount,
            format: VlcStereoMonitorCallbackFormat(
                formatFourCC: "FL32",
                sampleRate: input.sampleRate,
                channelCount: 2
            ),
            interleavedSamples: downmixSurround51ToStereo(input)
        )
        let driftFrames = callback.frameCount - input.frameCount
        let measurements = VlcLivePCMDownmixMeasurements(
            inputFrameCount: input.frameCount,
            outputFrameCount: callback.frameCount,
            latencyFrames: simulatedProcessingLatencyFrames,
            latencyMilliseconds: Double(simulatedProcessingLatencyFrames) / input.sampleRate.hertz * 1_000.0,
            driftFrames: driftFrames,
            driftPartsPerMillion: Double(driftFrames) / Double(input.frameCount) * 1_000_000.0
        )
        let sourceFormat = AudioFormatSummary(
            sampleRate: input.sampleRate,
            channelCount: input.channelCount,
            sampleFormat: "Float32",
            layoutName: input.layout.name
        )
        let outputFormat = AudioFormatSummary(
            sampleRate: input.sampleRate,
            channelCount: 2,
            sampleFormat: "Float32",
            layoutName: "Stereo"
        )
        let ledger = AudioConversionLedger(
            sessionID: "vlc-live-pcm-prototype-\(input.generation)",
            sourceID: input.sourceID,
            sourceKind: .roon,
            entries: [
                AudioConversionLedgerEntry(
                    stage: .capture,
                    owner: .roon,
                    output: sourceFormat,
                    isExplicit: true,
                    note: "Roon-decoded live PCM captured before optional monitor downmix prototype."
                ),
                AudioConversionLedgerEntry(
                    stage: .downmix,
                    owner: Self.downmixOwner,
                    input: sourceFormat,
                    output: outputFormat,
                    isExplicit: true,
                    note: "Optional VLC live PCM bridge selected for Roon monitor proof; latencyFrames=\(measurements.latencyFrames); driftFrames=\(measurements.driftFrames)."
                )
            ]
        )

        return VlcLivePCMDownmixPrototypeResult(
            rawStream: rawStream,
            callback: callback,
            downmixOwner: Self.downmixOwner,
            measurements: measurements,
            ledger: ledger
        )
    }

    private func makeRawStream(from input: VlcLivePCMInputBlock) -> VlcReadableRawPCMStream {
        var interleaved: [Float] = []
        interleaved.reserveCapacity(input.frameCount * input.channelCount)
        for frame in 0..<input.frameCount {
            for channel in 0..<input.channelCount {
                interleaved.append(input.sample(channel: channel, frame: frame))
            }
        }
        return VlcReadableRawPCMStream(
            formatFourCC: "FL32",
            sampleRate: input.sampleRate,
            channelCount: input.channelCount,
            frameStart: input.frameStart,
            frameCount: input.frameCount,
            interleavedSamples: interleaved
        )
    }

    private func downmixSurround51ToStereo(_ input: VlcLivePCMInputBlock) -> [Float] {
        var stereo: [Float] = []
        stereo.reserveCapacity(input.frameCount * 2)
        for frame in 0..<input.frameCount {
            let frontLeft = input.sample(channel: 0, frame: frame)
            let frontRight = input.sample(channel: 1, frame: frame)
            let center = input.sample(channel: 2, frame: frame)
            let lfe = input.sample(channel: 3, frame: frame)
            let sideLeft = input.sample(channel: 4, frame: frame)
            let sideRight = input.sample(channel: 5, frame: frame)

            stereo.append(frontLeft + center * 0.707_106_77 + lfe * 0.25 + sideLeft * 0.707_106_77)
            stereo.append(frontRight + center * 0.707_106_77 + lfe * 0.25 + sideRight * 0.707_106_77)
        }
        return stereo
    }
}
