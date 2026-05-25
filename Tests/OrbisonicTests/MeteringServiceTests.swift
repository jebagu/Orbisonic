import AVFoundation
import XCTest
@testable import Orbisonic

final class MeteringServiceTests: XCTestCase {
    func testDefaultReferenceMapsMinus18DbFSToZeroVU() {
        let service = MeteringService()
        ingestConstant(service: service, signal: .input, amplitude: amplitude(dbFS: -18), channelCount: 2)

        let levels = service.levels(signal: .input, channelCount: 2)

        XCTAssertEqual(levels.count, 2)
        XCTAssertEqual(levels[0].rawRMSDbFS, -18, accuracy: 0.05)
        XCTAssertEqual(levels[0].peakDbFS, -18, accuracy: 0.05)
        XCTAssertEqual(levels[0].vuDb, 0, accuracy: 0.05)
        XCTAssertEqual(levels[0].displayLevel, 36.0 / 42.0, accuracy: 0.002)
    }

    func testReferenceShiftsVUWithoutChangingRawDbFS() {
        let service = MeteringService()
        let amplitude = amplitude(dbFS: -18)
        ingestConstant(service: service, signal: .input, amplitude: amplitude)
        let defaultLevel = service.levels(signal: .input, channelCount: 1)[0]

        service.updateCalibration(
            VUMeterCalibrationSettings(
                referenceDbFS: -12,
                responseMode: .standard,
                monitorTrimDb: 0,
                sonicSphereTrimDb: 0
            )
        )
        let shiftedLevel = service.levels(signal: .input, channelCount: 1)[0]

        XCTAssertEqual(defaultLevel.rawRMSDbFS, shiftedLevel.rawRMSDbFS, accuracy: 0.001)
        XCTAssertEqual(shiftedLevel.vuDb, -6, accuracy: 0.05)
        XCTAssertLessThan(shiftedLevel.displayLevel, defaultLevel.displayLevel)
    }

    func testMeasuredQuietSignalBelowOldVisualFloorStillDisplaysLowTail() {
        let service = MeteringService()
        ingestConstant(service: service, signal: .input, amplitude: amplitude(dbFS: -70))

        let level = service.levels(signal: .input, channelCount: 1)[0]

        XCTAssertTrue(service.isActive(signal: .input))
        XCTAssertEqual(level.rawRMSDbFS, -70, accuracy: 0.05)
        XCTAssertEqual(level.peakDbFS, -70, accuracy: 0.05)
        XCTAssertLessThan(level.vuDb, -36)
        XCTAssertGreaterThan(level.displayLevel, 0)
        XCTAssertLessThan(level.displayLevel, 0.012)
    }

    func testQuietVisualTailFallsAsMeasuredSignalGetsQuieter() {
        let louder = MeteringService()
        let quieter = MeteringService()
        ingestConstant(service: louder, signal: .sonicSphere, amplitude: amplitude(dbFS: -60))
        ingestConstant(service: quieter, signal: .sonicSphere, amplitude: amplitude(dbFS: -80))

        let louderLevel = louder.levels(signal: .sonicSphere, channelCount: 1)[0]
        let quieterLevel = quieter.levels(signal: .sonicSphere, channelCount: 1)[0]

        XCTAssertTrue(louder.isActive(signal: .sonicSphere))
        XCTAssertTrue(quieter.isActive(signal: .sonicSphere))
        XCTAssertGreaterThan(louderLevel.displayLevel, quieterLevel.displayLevel)
        XCTAssertGreaterThan(quieterLevel.displayLevel, 0)
    }

    func testInactiveNearSilenceReleasesVisualDisplayInsteadOfSnappingToZero() {
        let service = MeteringService()
        ingestConstant(service: service, signal: .input, amplitude: amplitude(dbFS: -18))
        let activeLevel = service.levels(signal: .input, channelCount: 1)[0]

        ingestConstant(service: service, signal: .input, amplitude: amplitude(dbFS: -100))
        let nearSilenceRelease = service.levels(signal: .input, channelCount: 1)[0]

        XCTAssertFalse(service.isActive(signal: .input))
        XCTAssertEqual(nearSilenceRelease.rawRMSDbFS, -100, accuracy: 0.05)
        XCTAssertEqual(nearSilenceRelease.peakDbFS, -100, accuracy: 0.05)
        XCTAssertGreaterThan(nearSilenceRelease.displayLevel, 0)
        XCTAssertLessThan(nearSilenceRelease.displayLevel, activeLevel.displayLevel)

        ingestConstant(service: service, signal: .input, amplitude: 0)
        let silenceRelease = service.levels(signal: .input, channelCount: 1)[0]

        XCTAssertFalse(service.isActive(signal: .input))
        XCTAssertEqual(silenceRelease.rawRMSDbFS, MeterChannelLevel.silenceDbFS)
        XCTAssertEqual(silenceRelease.peakDbFS, MeterChannelLevel.silenceDbFS)
        XCTAssertGreaterThan(silenceRelease.displayLevel, 0)
        XCTAssertLessThan(silenceRelease.displayLevel, nearSilenceRelease.displayLevel)
    }

    func testMonitorAndSonicTrimsAffectDisplayOnly() {
        let service = MeteringService()
        let amplitude = amplitude(dbFS: -18)
        ingestConstant(service: service, signal: .monitor, amplitude: amplitude)
        ingestConstant(service: service, signal: .sonicSphere, amplitude: amplitude)

        let monitorBefore = service.levels(signal: .monitor, channelCount: 1)[0]
        let sonicBefore = service.levels(signal: .sonicSphere, channelCount: 1)[0]

        service.updateCalibration(
            VUMeterCalibrationSettings(
                referenceDbFS: -18,
                responseMode: .standard,
                monitorTrimDb: 3,
                sonicSphereTrimDb: -4
            )
        )

        let monitorAfter = service.levels(signal: .monitor, channelCount: 1)[0]
        let sonicAfter = service.levels(signal: .sonicSphere, channelCount: 1)[0]

        XCTAssertEqual(monitorBefore.rawRMSDbFS, monitorAfter.rawRMSDbFS, accuracy: 0.001)
        XCTAssertEqual(sonicBefore.rawRMSDbFS, sonicAfter.rawRMSDbFS, accuracy: 0.001)
        XCTAssertEqual(monitorAfter.vuDb, monitorBefore.vuDb + 3, accuracy: 0.001)
        XCTAssertEqual(sonicAfter.vuDb, sonicBefore.vuDb - 4, accuracy: 0.001)
    }

    func testInactiveSonicSphereStaysSilent() {
        let service = MeteringService()
        ingestConstant(service: service, signal: .sonicSphere, amplitude: amplitude(dbFS: -18), channelCount: 4)
        XCTAssertTrue(service.isActive(signal: .sonicSphere))

        service.setInactive(signal: .sonicSphere, channelCount: 4)
        let levels = service.levels(signal: .sonicSphere, channelCount: 4)

        XCTAssertFalse(service.isActive(signal: .sonicSphere))
        XCTAssertEqual(levels.count, 4)
        XCTAssertTrue(levels.allSatisfy { $0.displayLevel == 0 })
        XCTAssertTrue(levels.allSatisfy { $0.rawRMSDbFS == MeterChannelLevel.silenceDbFS })
    }

    func testResponseModeAffectsBallisticsOnly() {
        let smooth = MeteringService()
        let fast = MeteringService()
        smooth.updateCalibration(
            VUMeterCalibrationSettings(referenceDbFS: -18, responseMode: .smooth, monitorTrimDb: 0, sonicSphereTrimDb: 0)
        )
        fast.updateCalibration(
            VUMeterCalibrationSettings(referenceDbFS: -18, responseMode: .fast, monitorTrimDb: 0, sonicSphereTrimDb: 0)
        )

        ingestConstant(service: smooth, signal: .input, amplitude: amplitude(dbFS: -40))
        ingestConstant(service: fast, signal: .input, amplitude: amplitude(dbFS: -40))
        _ = smooth.levels(signal: .input, channelCount: 1)
        _ = fast.levels(signal: .input, channelCount: 1)
        ingestConstant(service: smooth, signal: .input, amplitude: amplitude(dbFS: -18))
        ingestConstant(service: fast, signal: .input, amplitude: amplitude(dbFS: -18))

        let smoothLevel = smooth.levels(signal: .input, channelCount: 1)[0]
        let fastLevel = fast.levels(signal: .input, channelCount: 1)[0]

        XCTAssertEqual(smoothLevel.rawRMSDbFS, fastLevel.rawRMSDbFS, accuracy: 0.001)
        XCTAssertEqual(smoothLevel.rawRMSDbFS, -18, accuracy: 0.05)
        XCTAssertGreaterThan(fastLevel.vuDb, smoothLevel.vuDb)
        XCTAssertGreaterThan(fastLevel.displayLevel, smoothLevel.displayLevel)
    }

    func testSilenceAndNearSilenceRemainInactive() {
        let service = MeteringService()
        ingestConstant(service: service, signal: .monitor, amplitude: 0, channelCount: 6)
        ingestConstant(service: service, signal: .sonicSphere, amplitude: 0.00001, channelCount: 31)

        XCTAssertFalse(service.isActive(signal: .monitor))
        XCTAssertFalse(service.isActive(signal: .sonicSphere))
        XCTAssertTrue(service.levels(signal: .monitor, channelCount: 6).allSatisfy { $0.displayLevel == 0 })
        XCTAssertTrue(service.levels(signal: .sonicSphere, channelCount: 31).allSatisfy { $0.displayLevel == 0 })
    }

    func testMeteringOverloadDropsChannelsAboveRealtimeCapacity() {
        let service = MeteringService()
        let overflowChannelCount = MeteringService.maxRealtimeChannelCount + 4
        let samples = (0..<overflowChannelCount).map { _ in Array(repeating: Float(0.25), count: 8) }

        service.ingest(signal: .input, sampleBuffers: samples, frameCount: 8)

        let status = service.status(signal: .input)
        XCTAssertEqual(status.channelCount, MeteringService.maxRealtimeChannelCount)
        XCTAssertEqual(status.maxChannelCount, MeteringService.maxRealtimeChannelCount)
        XCTAssertEqual(status.droppedChannelMeasurementCount, 4)
        XCTAssertTrue(service.isActive(signal: .input))
        XCTAssertEqual(
            service.levels(signal: .input, channelCount: overflowChannelCount).count,
            MeteringService.maxRealtimeChannelCount
        )
    }

    func testMeteringServiceCallbackIngressAvoidsLocksAndMeasurementArrays() throws {
        let sourceURL = packageRoot().appendingPathComponent("Sources/Orbisonic/MeteringService.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        XCTAssertFalse(source.contains("NSLock"))
        XCTAssertFalse(source.contains("compactMap"))
        XCTAssertFalse(source.contains("private var states"))
        XCTAssertFalse(source.contains("activeSignals"))
    }

    func testIngestMultichannelPCMBufferWindow() throws {
        let service = MeteringService()
        let buffer = try Self.makeMultichannelBuffer(channelCount: 2, frames: 64) { channel, frame in
            frame < 16 ? 0 : (channel == 0 ? 0.25 : -0.125)
        }

        service.ingest(signal: .input, buffer: buffer, startFrame: 16, frameCount: 32)
        let levels = service.levels(signal: .input, channelCount: 2)

        XCTAssertTrue(service.isActive(signal: .input))
        XCTAssertEqual(levels.count, 2)
        XCTAssertEqual(levels[0].rawRMSDbFS, MeteringServiceTests.dbFS(0.25), accuracy: 0.05)
        XCTAssertEqual(levels[1].rawRMSDbFS, MeteringServiceTests.dbFS(0.125), accuracy: 0.05)
        XCTAssertTrue(levels.allSatisfy { $0.displayLevel > 0 })
    }

    func testIngestSilentPCMBufferWindowStaysInactive() throws {
        let service = MeteringService()
        let buffer = try Self.makeMultichannelBuffer(channelCount: 2, frames: 64) { _, _ in 0 }

        service.ingest(signal: .input, buffer: buffer, startFrame: 16, frameCount: 32)
        let levels = service.levels(signal: .input, channelCount: 2)

        XCTAssertFalse(service.isActive(signal: .input))
        XCTAssertTrue(levels.allSatisfy { $0.displayLevel == 0 })
    }

    func testVersionFiveMigrationFromLegacyDefaultsResetsVisualBoostsAndInstallsSignalDefaults() {
        let suiteName = "OrbisonicTests.VUMeterDefaultsMigration.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(3, forKey: VUMeterDefaultsMigration.scaleVersionKey)
        defaults.set(7.0, forKey: "Orbisonic.vuMeterRendererVisualGainOffset")
        defaults.set(true, forKey: "Orbisonic.vuMeterNormalizesVisualEnergy")
        defaults.set(false, forKey: "Orbisonic.vuMeterMatchesPanelActivity")
        defaults.set(0.10, forKey: "Orbisonic.vuMeterActivityMatchStrength")
        defaults.set(-4.0, forKey: "Orbisonic.vuMeterRendererActivityTrimOffset")

        XCTAssertTrue(VUMeterDefaultsMigration.migrate(defaults: defaults))
        XCTAssertEqual(defaults.integer(forKey: VUMeterDefaultsMigration.scaleVersionKey), 5)
        XCTAssertNil(defaults.object(forKey: "Orbisonic.vuMeterRendererVisualGainOffset"))
        XCTAssertNil(defaults.object(forKey: "Orbisonic.vuMeterNormalizesVisualEnergy"))
        XCTAssertEqual(defaults.double(forKey: VUMeterDefaultsMigration.referenceDbFSKey), -18, accuracy: 0.001)
        XCTAssertEqual(defaults.string(forKey: VUMeterDefaultsMigration.responseModeKey), VUMeterResponseMode.standard.rawValue)
        XCTAssertEqual(defaults.double(forKey: VUMeterDefaultsMigration.monitorTrimDbKey), 0, accuracy: 0.001)
        XCTAssertEqual(defaults.double(forKey: VUMeterDefaultsMigration.sonicSphereTrimDbKey), 0, accuracy: 0.001)
    }

    func testVersionFiveMigrationFromVersionFourOnlyNeutralizesMonitorTrim() {
        let suiteName = "OrbisonicTests.VUMeterDefaultsMigration.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(4, forKey: VUMeterDefaultsMigration.scaleVersionKey)
        defaults.set(-17.5, forKey: VUMeterDefaultsMigration.referenceDbFSKey)
        defaults.set(VUMeterResponseMode.fast.rawValue, forKey: VUMeterDefaultsMigration.responseModeKey)
        defaults.set(-5.5, forKey: VUMeterDefaultsMigration.monitorTrimDbKey)
        defaults.set(1.75, forKey: VUMeterDefaultsMigration.sonicSphereTrimDbKey)

        XCTAssertTrue(VUMeterDefaultsMigration.migrate(defaults: defaults))

        XCTAssertEqual(defaults.integer(forKey: VUMeterDefaultsMigration.scaleVersionKey), 5)
        XCTAssertEqual(defaults.double(forKey: VUMeterDefaultsMigration.referenceDbFSKey), -17.5, accuracy: 0.001)
        XCTAssertEqual(defaults.string(forKey: VUMeterDefaultsMigration.responseModeKey), VUMeterResponseMode.fast.rawValue)
        XCTAssertEqual(defaults.double(forKey: VUMeterDefaultsMigration.monitorTrimDbKey), 0, accuracy: 0.001)
        XCTAssertEqual(defaults.double(forKey: VUMeterDefaultsMigration.sonicSphereTrimDbKey), 1.75, accuracy: 0.001)

        let settings = VUMeterDefaultsMigration.settings(defaults: defaults)
        XCTAssertEqual(settings.referenceDbFS, -17.5, accuracy: 0.001)
        XCTAssertEqual(settings.responseMode, .fast)
        XCTAssertEqual(settings.monitorTrimDb, 0, accuracy: 0.001)
        XCTAssertEqual(settings.sonicSphereTrimDb, 1.75, accuracy: 0.001)
    }

    private func ingestConstant(
        service: MeteringService,
        signal: MeterSignalID,
        amplitude: Float,
        channelCount: Int = 1,
        frames: Int = 1024
    ) {
        let buffers = (0..<channelCount).map { channelIndex -> AVAudioPCMBuffer in
            let format = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1)!
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames))!
            buffer.frameLength = AVAudioFrameCount(frames)
            let channelData = buffer.floatChannelData![0]
            for frame in 0..<frames {
                channelData[frame] = amplitude * (channelIndex.isMultiple(of: 2) ? 1 : -1)
            }
            return buffer
        }
        service.ingest(signal: signal, buffers: buffers, startFrame: 0, frameCount: frames)
    }

    private static func makeMultichannelBuffer(
        channelCount: AVAudioChannelCount,
        frames: AVAudioFrameCount,
        sample: (Int, Int) -> Float
    ) throws -> AVAudioPCMBuffer {
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: channelCount))
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames))
        buffer.frameLength = frames
        let channelData = try XCTUnwrap(buffer.floatChannelData)
        for channel in 0..<Int(channelCount) {
            for frame in 0..<Int(frames) {
                channelData[channel][frame] = sample(channel, frame)
            }
        }
        return buffer
    }

    private func amplitude(dbFS: Float) -> Float {
        powf(10, dbFS / 20)
    }

    private static func dbFS(_ value: Float) -> Float {
        20 * log10f(max(value, 0.000_001))
    }

    private func packageRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
