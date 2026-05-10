import AVFoundation
import XCTest
@testable import Orbisonic

final class LiveNormalMonitorRouteTests: XCTestCase {
    private let tolerance: Float = 1e-6

    func testRoonLiveUsesNormalMonitorOnly() {
        assertNormalMonitor(liveRoute(for: .roon))
        XCTAssertEqual(SourceMode.roon.expectedLoopback, .roonInput)
    }

    func testSpotifyLiveUsesNormalMonitorOnly() {
        assertNormalMonitor(liveRoute(for: .spotify))
        XCTAssertEqual(SourceMode.spotify.expectedLoopback, .spotifyInput)
        XCTAssertEqual(SourceMode.spotify.fixedLiveChannelCount, 2)
    }

    func testAuxLiveUsesNormalMonitorOnly() {
        assertNormalMonitor(liveRoute(for: .aux))
        XCTAssertEqual(SourceMode.aux.expectedLoopback, .auxCable)
    }

    func testAtmosDRPUsesTemporaryAuxLoopbackAndNormalMonitorOnly() {
        assertNormalMonitor(liveRoute(for: .atmosDRP))
        XCTAssertEqual(SourceMode.atmosDRP.expectedLoopback, .auxCable)
        XCTAssertEqual(AtmosDRPRoutingPolicy.captureLoopback, .auxCable)
        XCTAssertTrue(SourceMode.atmosDRP.ownsTransport)
    }

    func testBlackHoleLiveUsesNormalMonitorOnlyIfSupported() {
        assertNormalMonitor(legacyBlackHoleRoute())
        XCTAssertNil(SourceMode.allCases.first { $0.rawValue.localizedCaseInsensitiveContains("BlackHole") })
    }

    func testLiveNormalMonitorOutputsExactlyTwoChannels() {
        for route in liveRoutesIncludingLegacyBlackHole() {
            XCTAssertEqual(route.outputChannelCount, 2, route.sourceLayoutDescription)
            XCTAssertEqual(route.terminalRenderer, .normalMonitorStereoDownmixer, route.sourceLayoutDescription)
        }
    }

    func testLiveNormalMonitorNeverUsesSpatialFallback() {
        for route in liveRoutesIncludingLegacyBlackHole() {
            XCTAssertFalse(route.usesAVAudioEnvironmentNode, route.sourceLayoutDescription)
            XCTAssertFalse(route.usesHRTF, route.sourceLayoutDescription)
            XCTAssertFalse(route.usesHRTFHQ, route.sourceLayoutDescription)
            XCTAssertFalse(route.usesHeadphoneEnvironmentOutput, route.sourceLayoutDescription)
            XCTAssertFalse(route.usesPointSourceSpatialPlacement, route.sourceLayoutDescription)
        }
    }

    func testLiveNormalMonitorNeverUsesAudibleDirectSonicSphereMatrix() {
        for route in liveRoutesIncludingLegacyBlackHole() {
            XCTAssertFalse(route.usesAudibleDirectSonicSphereMatrix, route.sourceLayoutDescription)
        }

        let topology = NormalMonitorGraphTopology.audible(sourceFamily: .liveLoopback)
        XCTAssertFalse(topology.containsAudibleSonicSphereMatrixNode)
        XCTAssertFalse(topology.nodes.contains(.audibleSonicSphereMatrix))
    }

    func testLiveMonitorDownmixMatchesExpectedCoefficients() throws {
        let frameCount = 4
        let pipe = LiveAudioPipe(channelCount: 6, sampleRate: 48_000, latencySeconds: 0.01)
        writeSamples([
            ramp(start: 10, count: 4_096),
            ramp(start: 20, count: 4_096),
            ramp(start: 30, count: 4_096),
            ramp(start: 40, count: 4_096),
            ramp(start: 50, count: 4_096),
            ramp(start: 60, count: 4_096)
        ], to: pipe)

        let sourceSamples = (0..<6).map { channel in
            renderChannel(from: pipe, channelIndex: channel, frameCount: frameCount)
        }
        let layout = SurroundLayoutDetector.fallbackLayout(for: 6)
        let downmixed = try NormalMonitorStereoDownmixer(layout: layout, appliesHeadroom: false)
            .render(inputs: sourceSamples)

        let c = NormalMonitorDownmixMatrix.equalPowerCenter
        let expectedLeft = (0..<frameCount).map { frame -> Float in
            let offset = Float(frame)
            return (10 + offset) + ((30 + offset) * c) + ((50 + offset) * c)
        }
        let expectedRight = (0..<frameCount).map { frame -> Float in
            let offset = Float(frame)
            return (20 + offset) + ((30 + offset) * c) + ((60 + offset) * c)
        }

        assertSamples(downmixed, equals: [expectedLeft, expectedRight])
    }

    func testLiveMeterPeekDoesNotAffectPlaybackConsumption() throws {
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
        XCTAssertEqual(renderChannel(from: pipe, channelIndex: 0, frameCount: 4), [1, 2, 3, 4])
    }

    func testSwitchingLiveSourcesDoesNotLeaveDuplicatePaths() {
        let stale = staleTopology(sourceFamily: .liveLoopback)

        for transition in [(SourceMode.roon, SourceMode.spotify), (.spotify, .aux)] {
            XCTAssertTrue(transition.0.stopsLiveCaptureWhenSwitching(to: transition.1))

            let rebuilt = NormalMonitorGraphTopology.rebuilding(stale, for: .liveLoopback)
            XCTAssertEqual(rebuilt.sourceFamily, .liveLoopback)
            XCTAssertFalse(rebuilt.hasDuplicateDirectAndStagedRoutes)
            XCTAssertFalse(rebuilt.containsEnvironmentNode)
            XCTAssertFalse(rebuilt.containsAudibleSonicSphereMatrixNode)
            XCTAssertFalse(rebuilt.containsStaleConnections(for: .liveLoopback))
            XCTAssertTrue(rebuilt.hasExactlyOneAudiblePath)
            assertNormalMonitor(liveRoute(for: transition.1))
        }
    }

    func testSwitchingBetweenLocalAndLiveDoesNotLeaveStaleCallbacks() {
        let staleLive = staleTopology(sourceFamily: .liveLoopback)
        let switchedToLocal = NormalMonitorGraphTopology.rebuilding(staleLive, for: .localFile)

        XCTAssertTrue(SourceMode.aux.stopsLiveCaptureWhenSwitching(to: .filePlayback))
        XCTAssertFalse(switchedToLocal.edges.contains { $0.sourceFamily == .liveLoopback })
        XCTAssertFalse(switchedToLocal.containsStaleConnections(for: .localFile))
        XCTAssertFalse(switchedToLocal.hasDuplicateDirectAndStagedRoutes)
        XCTAssertTrue(switchedToLocal.hasExactlyOneAudiblePath)
        assertNormalMonitor(NormalMonitorRoutePlanner.route(
            for: .filePlayback,
            sourceLayoutDescription: "local file after live source"
        ), expectedSourceFamily: .localFile)

        let switchedBackToLive = NormalMonitorGraphTopology.rebuilding(switchedToLocal, for: .liveLoopback)
        XCTAssertFalse(switchedBackToLive.edges.contains { $0.sourceFamily == .localFile })
        XCTAssertFalse(switchedBackToLive.containsStaleConnections(for: .liveLoopback))
        XCTAssertFalse(switchedBackToLive.hasDuplicateDirectAndStagedRoutes)
        XCTAssertTrue(switchedBackToLive.hasExactlyOneAudiblePath)
        assertNormalMonitor(liveRoute(for: .roon))
    }

    private func liveRoute(for mode: SourceMode) -> NormalMonitorRouteDescriptor {
        XCTAssertTrue(mode.isLiveInput, "\(mode.rawValue) should be a live loopback source")
        return NormalMonitorRoutePlanner.route(
            for: mode,
            sourceLayoutDescription: "\(mode.rawValue) Core Audio PCM"
        )
    }

    private func legacyBlackHoleRoute() -> NormalMonitorRouteDescriptor {
        NormalMonitorRoutePlanner.audibleRoute(
            sourceFamily: .liveLoopback,
            sourceLayoutDescription: "Legacy BlackHole Core Audio PCM",
            warningDescriptions: ["Legacy BlackHole is treated as a loopback PCM source only."]
        )
    }

    private func liveRoutesIncludingLegacyBlackHole() -> [NormalMonitorRouteDescriptor] {
        [
            liveRoute(for: .roon),
            liveRoute(for: .spotify),
            liveRoute(for: .aux),
            legacyBlackHoleRoute()
        ]
    }

    private func assertNormalMonitor(
        _ route: NormalMonitorRouteDescriptor,
        expectedSourceFamily: NormalMonitorSourceFamily = .liveLoopback,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(route.sourceFamily, expectedSourceFamily, file: file, line: line)
        XCTAssertTrue(route.usesNormalMonitor, file: file, line: line)
        XCTAssertTrue(route.usesStereoDownmix, file: file, line: line)
        XCTAssertEqual(route.outputChannelCount, 2, file: file, line: line)
        XCTAssertEqual(route.terminalRenderer, .normalMonitorStereoDownmixer, file: file, line: line)
        XCTAssertFalse(route.usesAVAudioEnvironmentNode, file: file, line: line)
        XCTAssertFalse(route.usesHRTF, file: file, line: line)
        XCTAssertFalse(route.usesHRTFHQ, file: file, line: line)
        XCTAssertFalse(route.usesHeadphoneEnvironmentOutput, file: file, line: line)
        XCTAssertFalse(route.usesPointSourceSpatialPlacement, file: file, line: line)
        XCTAssertFalse(route.usesAudibleDirectSonicSphereMatrix, file: file, line: line)
        XCTAssertFalse(route.hasDuplicateAudiblePath, file: file, line: line)
    }

    private func renderChannel(
        from pipe: LiveAudioPipe,
        channelIndex: Int,
        frameCount: Int
    ) -> [Float] {
        let outputFormat = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1)!
        let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: outputFormat,
            frameCapacity: AVAudioFrameCount(frameCount)
        )!
        outputBuffer.frameLength = AVAudioFrameCount(frameCount)

        XCTAssertEqual(
            pipe.render(
                channelIndex: channelIndex,
                audioBufferList: outputBuffer.mutableAudioBufferList,
                frameCount: AVAudioFrameCount(frameCount)
            ),
            noErr
        )

        return samples(from: outputBuffer)[0]
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

    private func writeSamples(_ samples: [[Float]], to pipe: LiveAudioPipe) {
        let channelCount = samples.count
        let frameCount = samples.first?.count ?? 0
        let bufferList = allocateBufferList(channelCount: channelCount, frameCount: frameCount)
        defer {
            releaseBufferList(bufferList)
        }

        let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
        for channel in samples.indices {
            let destination = buffers[channel].mData!.assumingMemoryBound(to: Float.self)
            samples[channel].withUnsafeBufferPointer { source in
                destination.initialize(from: source.baseAddress!, count: frameCount)
            }
        }

        pipe.write(bufferList: buffers, frameCount: frameCount)
    }

    private func allocateBufferList(
        channelCount: Int,
        frameCount: Int
    ) -> UnsafeMutablePointer<AudioBufferList> {
        let byteCount = MemoryLayout<AudioBufferList>.size
            + MemoryLayout<AudioBuffer>.stride * max(channelCount - 1, 0)
        let rawBufferList = UnsafeMutableRawPointer.allocate(
            byteCount: byteCount,
            alignment: MemoryLayout<AudioBufferList>.alignment
        )
        rawBufferList.initializeMemory(as: UInt8.self, repeating: 0, count: byteCount)

        let bufferList = rawBufferList.bindMemory(to: AudioBufferList.self, capacity: 1)
        bufferList.pointee.mNumberBuffers = UInt32(channelCount)

        let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
        let dataByteCount = frameCount * MemoryLayout<Float>.size
        for index in buffers.indices {
            let channelData = UnsafeMutableRawPointer.allocate(
                byteCount: dataByteCount,
                alignment: MemoryLayout<Float>.alignment
            )
            channelData.initializeMemory(as: Float.self, repeating: 0, count: frameCount)
            buffers[index] = AudioBuffer(
                mNumberChannels: 1,
                mDataByteSize: UInt32(dataByteCount),
                mData: channelData
            )
        }

        return bufferList
    }

    private func releaseBufferList(_ bufferList: UnsafeMutablePointer<AudioBufferList>) {
        let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
        for index in buffers.indices {
            buffers[index].mData?.deallocate()
        }
        UnsafeMutableRawPointer(bufferList).deallocate()
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

    private func staleTopology(sourceFamily: NormalMonitorSourceFamily) -> NormalMonitorGraphTopology {
        NormalMonitorGraphTopology(
            sourceFamily: sourceFamily,
            nodes: [
                .sourcePCM,
                .normalMonitorStereoDownmixer,
                .outputGainMixer,
                .mainMixerNode,
                .systemOutput,
                .avAudioEnvironmentNode,
                .audibleSonicSphereMatrix
            ],
            edges: [
                NormalMonitorGraphEdge(sourceFamily: sourceFamily, from: .sourcePCM, to: .normalMonitorStereoDownmixer),
                NormalMonitorGraphEdge(sourceFamily: sourceFamily, from: .normalMonitorStereoDownmixer, to: .outputGainMixer),
                NormalMonitorGraphEdge(sourceFamily: sourceFamily, from: .outputGainMixer, to: .mainMixerNode),
                NormalMonitorGraphEdge(sourceFamily: sourceFamily, from: .sourcePCM, to: .mainMixerNode),
                NormalMonitorGraphEdge(sourceFamily: sourceFamily, from: .sourcePCM, to: .avAudioEnvironmentNode),
                NormalMonitorGraphEdge(sourceFamily: sourceFamily, from: .sourcePCM, to: .audibleSonicSphereMatrix),
                NormalMonitorGraphEdge(sourceFamily: sourceFamily, from: .mainMixerNode, to: .systemOutput)
            ],
            gainStages: [
                NormalMonitorGraphGainStage(node: .outputGainMixer, gain: 0.92, appliesMonitorVolume: true),
                NormalMonitorGraphGainStage(node: .mainMixerNode, gain: 0.92, appliesMonitorVolume: true)
            ]
        )
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
