import AVFoundation
import XCTest
@testable import Orbisonic

final class MeteringIsolationTests: XCTestCase {
    private let tolerance: Float = 1e-6

    func testMeteringComputesPeakDBFS() {
        let service = MeteringService()

        service.ingest(
            signal: .monitor,
            sampleBuffers: [[0, -0.5, 0.25, 0.125]],
            frameCount: 4
        )

        let level = service.levels(signal: .monitor, channelCount: 1)[0]
        XCTAssertEqual(level.peakDbFS, dbFS(0.5), accuracy: 0.0001)
    }

    func testMeteringComputesRMSDBFS() {
        let service = MeteringService()
        let samples: [Float] = [0.5, -0.25, 0, 0.25]

        service.ingest(
            signal: .monitor,
            sampleBuffers: [samples],
            frameCount: samples.count
        )

        let expectedRMS = sqrtf(samples.map { $0 * $0 }.reduce(0, +) / Float(samples.count))
        let level = service.levels(signal: .monitor, channelCount: 1)[0]
        XCTAssertEqual(level.rawRMSDbFS, dbFS(expectedRMS), accuracy: 0.0001)
    }

    func testMeteringSilenceUsesDefinedFloorOrNegativeInfinity() {
        let service = MeteringService()

        service.ingest(
            signal: .monitor,
            sampleBuffers: [[0, 0, 0, 0]],
            frameCount: 4
        )

        let level = service.levels(signal: .monitor, channelCount: 1)[0]
        XCTAssertEqual(level.rawRMSDbFS, MeterChannelLevel.silenceDbFS)
        XCTAssertEqual(level.peakDbFS, MeterChannelLevel.silenceDbFS)
        XCTAssertEqual(level.displayLevel, 0)
        XCTAssertFalse(service.isActive(signal: .monitor))
    }

    func testMeteringDoesNotMutateInputBuffers() {
        let service = MeteringService()
        let sampleBuffers: [[Float]] = [
            [1, -0.5, 0.25, -0.125],
            [-0.25, 0.125, -0.0625, 0.03125]
        ]
        let original = sampleBuffers
        let pcmBuffer = makePCMBuffer(sampleBuffers)
        let originalPCM = samples(from: pcmBuffer)

        service.ingest(signal: .input, sampleBuffers: sampleBuffers, frameCount: 4)
        service.ingest(
            signal: .monitor,
            bufferList: UnsafeMutableAudioBufferListPointer(pcmBuffer.mutableAudioBufferList),
            frameCount: 4
        )

        XCTAssertEqual(sampleBuffers, original)
        assertSamples(samples(from: pcmBuffer), equals: originalPCM)
    }

    func testMonitorTapDoesNotChangeAudibleSamples() throws {
        let layout = SurroundLayoutDetector.fallbackLayout(for: 2)
        let input: [[Float]] = [
            [0.1, 0.2, 0.3, 0.4],
            [-0.4, -0.3, -0.2, -0.1]
        ]
        let downmixer = NormalMonitorStereoDownmixer(layout: layout)
        let beforeTap = try downmixer.render(inputs: input)
        let tapBuffer = makePCMBuffer(beforeTap)
        let tapOriginal = samples(from: tapBuffer)
        let service = MeteringService()

        service.ingest(
            signal: .monitor,
            bufferList: UnsafeMutableAudioBufferListPointer(tapBuffer.mutableAudioBufferList),
            frameCount: beforeTap[0].count
        )
        let afterTap = try downmixer.render(inputs: input)

        assertSamples(samples(from: tapBuffer), equals: tapOriginal)
        assertSamples(afterTap, equals: beforeTap)
    }

    func testMeterOnlyRenderUsesSeparateBuffers() {
        let input: [[Float]] = [
            [1, 2, 3, 4],
            [5, 6, 7, 8]
        ]
        let matrix = RendererMatrix(gains: [
            [1, 0],
            [0, 1]
        ])
        let rendered = RendererMatrixSampleRenderer.renderSampleBuffers(
            matrix: matrix,
            inputSamples: input,
            frameCount: 4
        )

        XCTAssertEqual(rendered.frameCount, 4)
        assertSamples(rendered.sampleBuffers, equals: input)
        XCTAssertNotEqual(bufferAddress(input[0]), bufferAddress(rendered.sampleBuffers[0]))
        XCTAssertNotEqual(bufferAddress(input[1]), bufferAddress(rendered.sampleBuffers[1]))
    }

    func testMeterOnlyRenderDoesNotWriteToPlaybackOutput() {
        let input: [[Float]] = [
            [1, 2, 3, 4],
            [5, 6, 7, 8]
        ]
        let matrix = RendererMatrix(gains: [
            [0.5, 0.25],
            [0.75, 1.25]
        ])
        let playbackOutput: [[Float]] = [
            [99, 99, 99, 99],
            [88, 88, 88, 88]
        ]
        let originalPlaybackOutput = playbackOutput

        _ = RendererMatrixSampleRenderer.renderSampleBuffers(
            matrix: matrix,
            inputSamples: input,
            frameCount: 4
        )

        XCTAssertEqual(playbackOutput, originalPlaybackOutput)
    }

    func testLiveMeterPeekDoesNotConsumeRingBufferSamples() throws {
        let service = MeteringService()
        let pipe = LiveAudioPipe(
            channelCount: 2,
            sampleRate: 48_000,
            latencySeconds: 0.01,
            meteringService: service
        )
        let input = makePCMBuffer([
            ramp(start: 1, count: 4_096),
            ramp(start: -1, count: 4_096)
        ])
        pipe.write(buffer: input)
        let before = try XCTUnwrap(pipe.status())

        XCTAssertTrue(pipe.renderMeterSnapshot(matrix: RendererMatrix(gains: [[1, 0], [0, 1]]), frameCount: 512))

        let after = try XCTUnwrap(pipe.status())
        XCTAssertEqual(after, before)
        XCTAssertTrue(service.isActive(signal: .sonicSphere))

        let outputFormat = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1)!
        let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: 4)!
        outputBuffer.frameLength = 4
        XCTAssertEqual(pipe.render(channelIndex: 0, audioBufferList: outputBuffer.mutableAudioBufferList, frameCount: 4), noErr)
        assertSamples(samples(from: outputBuffer), equals: [[1, 2, 3, 4]])
    }

    func testAudioOutputIdenticalWithMetersEnabledAndDisabled() throws {
        let layout = SurroundLayoutDetector.fallbackLayout(for: 6)
        let input: [[Float]] = [
            [10, 11, 12, 13],
            [20, 21, 22, 23],
            [30, 31, 32, 33],
            [40, 41, 42, 43],
            [50, 51, 52, 53],
            [60, 61, 62, 63]
        ]
        let baseline = try NormalMonitorStereoDownmixer(layout: layout, appliesHeadroom: false)
            .render(inputs: input)
        let service = MeteringService()

        service.ingest(signal: .input, sampleBuffers: input, frameCount: 4)
        service.ingest(signal: .monitor, sampleBuffers: baseline, frameCount: 4)
        _ = RendererMatrixSampleRenderer.renderSampleBuffers(
            matrix: RendererMatrix(gains: [[1, 0], [0, 1], [0.5, 0.5], [0, 0], [0.25, 0], [0, 0.25]]),
            inputSamples: input,
            frameCount: 4
        )
        let afterMetering = try NormalMonitorStereoDownmixer(layout: layout, appliesHeadroom: false)
            .render(inputs: input)

        assertSamples(afterMetering, equals: baseline)
    }

    func testMeteringCannotChangeRouteAwayFromNormalMonitor() {
        let service = MeteringService()
        let before = NormalMonitorRoutePlanner.audibleRoute(
            sourceFamily: .localFile,
            sourceLayoutDescription: "5.1 normal monitor"
        )

        service.ingest(signal: .input, sampleBuffers: [[0.5, -0.5, 0.25, -0.25]], frameCount: 4)
        service.ingest(signal: .monitor, sampleBuffers: [[0.25, -0.25, 0.125, -0.125]], frameCount: 4)
        service.ingest(signal: .sonicSphere, sampleBuffers: [[0.125, -0.125, 0.0625, -0.0625]], frameCount: 4)

        let after = NormalMonitorRoutePlanner.audibleRoute(
            sourceFamily: .localFile,
            sourceLayoutDescription: "5.1 normal monitor"
        )
        XCTAssertEqual(after, before)
        assertNormalMonitor(after)
    }

    func testMeteringCannotEnableSpatialOrDirectRendererOutput() {
        let service = MeteringService()
        service.ingest(signal: .sonicSphere, sampleBuffers: [[0.5, 0.25, -0.25, -0.5]], frameCount: 4)

        XCTAssertTrue(AudioSpatialUsageAudit.audiblePlaybackDescriptors.allSatisfy(NormalMonitorSpatialGuard.validatesAudiblePlayback))
        for sourceFamily in NormalMonitorSourceFamily.allCases {
            let route = NormalMonitorRoutePlanner.audibleRoute(
                sourceFamily: sourceFamily,
                sourceLayoutDescription: "\(sourceFamily.rawValue) metered"
            )
            assertNormalMonitor(route)
            XCTAssertFalse(route.usesAVAudioEnvironmentNode)
            XCTAssertFalse(route.usesHRTF)
            XCTAssertFalse(route.usesHRTFHQ)
            XCTAssertFalse(route.usesAudibleDirectSonicSphereMatrix)
        }
        for topology in NormalMonitorGraphTopology.audibleTopologies() {
            XCTAssertFalse(topology.containsEnvironmentNode)
            XCTAssertFalse(topology.containsAudibleSonicSphereMatrixNode)
            XCTAssertTrue(topology.hasExactlyOneAudiblePath)
        }
    }

    private func assertNormalMonitor(
        _ route: NormalMonitorRouteDescriptor,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(route.usesNormalMonitor, file: file, line: line)
        XCTAssertTrue(route.usesStereoDownmix, file: file, line: line)
        XCTAssertEqual(route.outputChannelCount, 2, file: file, line: line)
        XCTAssertFalse(route.usesAVAudioEnvironmentNode, file: file, line: line)
        XCTAssertFalse(route.usesHRTF, file: file, line: line)
        XCTAssertFalse(route.usesHRTFHQ, file: file, line: line)
        XCTAssertFalse(route.usesHeadphoneEnvironmentOutput, file: file, line: line)
        XCTAssertFalse(route.usesPointSourceSpatialPlacement, file: file, line: line)
        XCTAssertFalse(route.usesAudibleDirectSonicSphereMatrix, file: file, line: line)
        XCTAssertFalse(route.hasDuplicateAudiblePath, file: file, line: line)
    }

    private func makePCMBuffer(_ samples: [[Float]]) -> AVAudioPCMBuffer {
        let channelCount = AVAudioChannelCount(samples.count)
        let frameCount = samples.first?.count ?? 0
        let format = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: channelCount)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount))!
        buffer.frameLength = AVAudioFrameCount(frameCount)
        let channelData = buffer.floatChannelData!
        for channel in samples.indices {
            for frame in samples[channel].indices {
                channelData[channel][frame] = samples[channel][frame]
            }
        }
        return buffer
    }

    private func samples(from buffer: AVAudioPCMBuffer) -> [[Float]] {
        guard let channelData = buffer.floatChannelData else { return [] }
        let channelCount = Int(buffer.format.channelCount)
        let frameCount = Int(buffer.frameLength)
        return (0..<channelCount).map { channel in
            (0..<frameCount).map { frame in
                channelData[channel][frame]
            }
        }
    }

    private func ramp(start: Float, count: Int) -> [Float] {
        (0..<count).map { start + Float($0) }
    }

    private func dbFS(_ value: Float) -> Float {
        20 * log10f(max(value, 0.000_001))
    }

    private func bufferAddress(_ samples: [Float]) -> Int {
        samples.withUnsafeBufferPointer { buffer in
            Int(bitPattern: buffer.baseAddress)
        }
    }

    private func assertSamples(
        _ actual: [[Float]],
        equals expected: [[Float]],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(actual.count, expected.count, file: file, line: line)
        for channelIndex in expected.indices {
            XCTAssertEqual(actual[channelIndex].count, expected[channelIndex].count, file: file, line: line)
            for frameIndex in expected[channelIndex].indices {
                XCTAssertEqual(
                    actual[channelIndex][frameIndex],
                    expected[channelIndex][frameIndex],
                    accuracy: tolerance,
                    "channel \(channelIndex) frame \(frameIndex)",
                    file: file,
                    line: line
                )
            }
        }
    }
}
