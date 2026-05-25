import AVFoundation
import XCTest
@testable import Orbisonic

final class SonicSphereMeteringTests: XCTestCase {
    func testOrbitalVUMonitorSnapshotMapsOnlyToMonitorMarkers() {
        let monitorLayout = SurroundLayoutDetector.fallbackLayout(for: 2)
        let snapshot = OrbitalVUMeterSnapshot(
            source: .desktopOutput,
            meterLevels: [
                orbitalMeterLevel(0.42, peakDbFS: -18),
                orbitalMeterLevel(0.31, peakDbFS: -21)
            ],
            isActive: true
        )

        let monitorState = OrbitalVUMeterModel.monitorState(
            channels: monitorLayout.channels,
            meterSnapshot: snapshot
        )

        XCTAssertEqual(monitorState.meterSourceLabel, "Desktop Output Meter")
        XCTAssertTrue(monitorState.isActualAudibleOutput)
        XCTAssertEqual(monitorState.markers.count, 2)
        XCTAssertEqual(monitorState.markers.map(\.role), [.monitor, .monitor])
        XCTAssertEqual(monitorState.markers.map(\.label), ["L", "R"])
        XCTAssertEqual(monitorState.markers.map(\.normalizedLevel), [0.42, 0.31])
        XCTAssertTrue(monitorState.hasActiveMarkers)

        let scene = RendererMatrixBuilder.sceneModel(
            for: monitorLayout,
            preset: .sonicSphere30Point1,
            renderMode: .automatic
        )
        let sonicSphereState = OrbitalVUMeterModel.sonicSphereOutputState(
            scene: scene,
            meterSnapshot: snapshot
        )

        XCTAssertEqual(sonicSphereState.meterSourceLabel, "Desktop Output Meter")
        XCTAssertTrue(sonicSphereState.isActualAudibleOutput)
        XCTAssertTrue(sonicSphereState.markers.isEmpty)
        XCTAssertFalse(sonicSphereState.hasActiveMarkers)
    }

    func testOrbitalVUSonicSphereAnalysisMapsThirtyPointOneMarkers() {
        let scene = RendererMatrixBuilder.sceneModel(
            for: SurroundLayoutDetector.fallbackLayout(for: 31),
            preset: .sonicSphere30Point1,
            renderMode: .automatic
        )
        let levels = (0..<31).map { index in
            orbitalMeterLevel(index == 30 ? 0.27 : 0.12, peakDbFS: index == 30 ? -16 : -30)
        }
        let snapshot = OrbitalVUMeterSnapshot(
            source: .sonicSphereAnalysis,
            meterLevels: levels,
            isActive: true
        )

        let state = OrbitalVUMeterModel.sonicSphereOutputState(
            scene: scene,
            meterSnapshot: snapshot
        )

        XCTAssertEqual(state.meterSourceLabel, "Sonic Sphere Analysis Meter")
        XCTAssertFalse(state.isActualAudibleOutput)
        XCTAssertEqual(state.markers.count, 31)
        XCTAssertEqual(state.markers.filter { $0.role == .sonicSphereFullRange }.count, 30)
        XCTAssertEqual(state.markers.filter { $0.role == .sonicSphereLFE }.count, 1)
        XCTAssertEqual(state.markers.first?.label, "1")
        XCTAssertEqual(state.markers.last?.label, "LFE")
        XCTAssertEqual(state.markers.last?.normalizedLevel, 0.27)
        XCTAssertTrue(state.hasActiveMarkers)
        XCTAssertTrue(state.markers.allSatisfy { $0.meterSourceLabel == "Sonic Sphere Analysis Meter" })
        XCTAssertTrue(state.markers.allSatisfy { !$0.isActualAudibleOutput })
    }

    func testOrbitalVUPhysicalThirtyTwoKeepsChannelThirtyTwoReservedSilent() {
        let scene = RendererMatrixBuilder.sceneModel(
            for: SurroundLayoutDetector.fallbackLayout(for: 31),
            preset: .sonicSphere30Point1,
            renderMode: .automatic
        )
        var levels = Array(repeating: orbitalMeterLevel(0.08, peakDbFS: -42), count: 31)
        levels.append(orbitalMeterLevel(1.0, peakDbFS: 0))
        let snapshot = OrbitalVUMeterSnapshot(
            source: .danteOutput,
            meterLevels: levels,
            isActive: true
        )

        let state = OrbitalVUMeterModel.sonicSphereOutputState(
            scene: scene,
            meterSnapshot: snapshot,
            physicalOutputChannelCount: 32
        )

        XCTAssertEqual(state.meterSourceLabel, "Dante Output Meter")
        XCTAssertTrue(state.isActualAudibleOutput)
        XCTAssertEqual(state.markers.count, 32)

        let reserved = state.markers[31]
        XCTAssertEqual(reserved.channelID, "reserved-output-32")
        XCTAssertEqual(reserved.label, "32")
        XCTAssertEqual(reserved.role, .reservedPhysicalOutput)
        XCTAssertEqual(reserved.normalizedLevel, 0)
        XCTAssertFalse(reserved.isActive)
        XCTAssertFalse(reserved.isHot)
        XCTAssertFalse(reserved.isClipping)
        XCTAssertEqual(reserved.meterSourceLabel, "Dante Output Meter")
        XCTAssertTrue(reserved.isActualAudibleOutput)
    }

    func testOrbitalVUInactiveAndAllZeroMetersStayInactive() {
        let scene = RendererMatrixBuilder.sceneModel(
            for: SurroundLayoutDetector.fallbackLayout(for: 31),
            preset: .sonicSphere30Point1,
            renderMode: .automatic
        )
        let snapshot = OrbitalVUMeterSnapshot(
            source: .sonicSphereAnalysis,
            meterLevels: Array(repeating: .silence, count: 31),
            isActive: false
        )

        let state = OrbitalVUMeterModel.sonicSphereOutputState(
            scene: scene,
            meterSnapshot: snapshot
        )

        XCTAssertEqual(state.markers.count, 31)
        XCTAssertFalse(state.hasActiveMarkers)
        XCTAssertTrue(state.markers.allSatisfy { $0.normalizedLevel == 0 })
        XCTAssertTrue(state.markers.allSatisfy { !$0.isActive })
        XCTAssertTrue(state.markers.allSatisfy { !$0.isHot })
        XCTAssertTrue(state.markers.allSatisfy { !$0.isClipping })
    }

    func testOrbitalVUMeterModelDoesNotImportAudioGraphOrSceneTypes() throws {
        let source = try String(
            contentsOf: packageRoot().appendingPathComponent("Sources/Orbisonic/OrbitalVUMeterModel.swift"),
            encoding: .utf8
        )
        let forbiddenTokens = [
            "AVAudioEngine",
            "AVAudioPCMBuffer",
            "AudioBufferList",
            "AudioUnit",
            "SCNNode",
            "SceneKit",
            "installTap",
            "AudioDeviceID",
            "AVFoundation"
        ]

        for token in forbiddenTokens {
            XCTAssertFalse(source.contains(token), "Orbital VU model should not reference \(token)")
        }
    }

    @MainActor
    func testMeterOnlySonicSphereBusWorksWithoutDirectRendererAudio() throws {
        let engine = OrbisonicEngine()
        defer { engine.stop() }

        let loaded = makeLoadedFile(channelCount: 6, frames: 96_000, amplitude: amplitude(dbFS: -18))
        let committed = engine.loadPreparedFile(loaded)
        let scene = RendererMatrixBuilder.sceneModel(
            for: committed.layout,
            preset: .sonicSphere30Point1,
            renderMode: .surround51
        )

        engine.updateRenderer(mode: scene.renderMode, scene: scene)
        try engine.play()

        let beforeVolumeChange = engine.sonicSphereMeterLevels(channelCount: scene.matrix.outputCount)
        engine.setOutputVolume(0)
        let mutedOutput = engine.sonicSphereMeterLevels(channelCount: scene.matrix.outputCount)
        engine.setOutputVolume(1)
        let fullOutput = engine.sonicSphereMeterLevels(channelCount: scene.matrix.outputCount)

        XCTAssertTrue(engine.sonicSphereMeterIsActive())
        XCTAssertEqual(beforeVolumeChange.count, scene.matrix.outputCount)
        XCTAssertTrue(beforeVolumeChange.contains { $0.peakDbFS > MeterChannelLevel.activePeakFloorDbFS })
        XCTAssertTrue(beforeVolumeChange.contains { $0.displayLevel > 0 })
        XCTAssertEqual(mutedOutput.map(\.rawRMSDbFS), beforeVolumeChange.map(\.rawRMSDbFS))
        XCTAssertEqual(fullOutput.map(\.rawRMSDbFS), beforeVolumeChange.map(\.rawRMSDbFS))
    }

    func testRendererMatrixSampleRendererMatchesAudioBufferListRender() {
        let matrix = RendererMatrix(gains: [
            [1.0, 0.5],
            [0.25, 1.0]
        ])
        let sourceBuffers = Self.makeMonoBuffers(channelCount: 2, frames: 32, amplitude: 0.25)
        let renderedSamples = RendererMatrixSampleRenderer.renderSampleBuffers(
            matrix: matrix,
            sourceBuffers: sourceBuffers,
            startFrame: 0,
            frameCount: 32
        )

        let outputFormat = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2)!
        let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: 32)!
        outputBuffer.frameLength = 32
        let renderedFrames = RendererMatrixSampleRenderer.render(
            matrix: matrix,
            sourceBuffers: sourceBuffers,
            startFrame: 0,
            frameCount: 32,
            outputBuffers: UnsafeMutableAudioBufferListPointer(outputBuffer.mutableAudioBufferList)
        )

        XCTAssertEqual(renderedSamples.frameCount, 32)
        XCTAssertEqual(renderedFrames, 32)
        let output = outputBuffer.floatChannelData!
        for channel in 0..<2 {
            for frame in 0..<32 {
                XCTAssertEqual(output[channel][frame], renderedSamples.sampleBuffers[channel][frame], accuracy: 0.000_001)
            }
        }
    }

    func testLiveMeterSnapshotDoesNotConsumeRingBuffers() throws {
        let service = MeteringService()
        let pipe = LiveAudioPipe(
            channelCount: 2,
            sampleRate: 48_000,
            latencySeconds: 0.01,
            meteringService: service
        )
        let inputFormat = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2)!
        let inputBuffer = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: 4_096)!
        inputBuffer.frameLength = 4_096
        for channel in 0..<2 {
            let channelData = inputBuffer.floatChannelData![channel]
            for frame in 0..<4_096 {
                channelData[frame] = channel == 0 ? 0.25 : -0.125
            }
        }

        pipe.write(buffer: inputBuffer)
        let before = try XCTUnwrap(pipe.status())

        XCTAssertTrue(pipe.renderMeterSnapshot(matrix: RendererMatrix(gains: [[1, 0], [0, 1]]), frameCount: 512))

        let after = try XCTUnwrap(pipe.status())
        XCTAssertEqual(after.minimumBufferedFrames, before.minimumBufferedFrames)
        XCTAssertEqual(after.maximumBufferedFrames, before.maximumBufferedFrames)
        XCTAssertEqual(after.underflowCount, before.underflowCount)
        XCTAssertEqual(after.underflowFrames, before.underflowFrames)
        XCTAssertTrue(service.isActive(signal: .sonicSphere))
    }

    private func makeLoadedFile(channelCount: Int, frames: Int, amplitude: Float) -> LoadedAudioFile {
        let sampleRate = 48_000.0
        let layout = SurroundLayoutDetector.fallbackLayout(for: channelCount)
        let monoFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let buffers = Self.makeMonoBuffers(channelCount: channelCount, frames: frames, amplitude: amplitude)
        let metadata = AudioSourceMetadata(
            fileName: "meter-only.wav",
            containerName: "WAV",
            codecName: "Float32",
            layoutName: layout.name,
            channelSummary: layout.channelSummary,
            channelCount: channelCount,
            sampleRate: sampleRate,
            bitDepth: 32,
            duration: Double(frames) / sampleRate
        )
        return LoadedAudioFile(
            url: URL(fileURLWithPath: "meter-only.wav"),
            monoFormat: monoFormat,
            sampleRate: sampleRate,
            frameCount: AVAudioFramePosition(frames),
            layout: layout,
            metadata: metadata,
            monoBuffers: buffers
        )
    }

    private static func makeMonoBuffers(channelCount: Int, frames: Int, amplitude: Float) -> [AVAudioPCMBuffer] {
        let format = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1)!
        return (0..<channelCount).map { channel in
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames))!
            buffer.frameLength = AVAudioFrameCount(frames)
            let channelData = buffer.floatChannelData![0]
            for frame in 0..<frames {
                channelData[frame] = channel.isMultiple(of: 2) ? amplitude : -amplitude
            }
            return buffer
        }
    }

    private func amplitude(dbFS: Float) -> Float {
        powf(10, dbFS / 20)
    }

    private func orbitalMeterLevel(_ level: Float, peakDbFS: Float) -> MeterChannelLevel {
        MeterChannelLevel(
            rawRMSDbFS: peakDbFS,
            peakDbFS: peakDbFS,
            vuDb: peakDbFS,
            displayLevel: level
        )
    }

    private func packageRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
