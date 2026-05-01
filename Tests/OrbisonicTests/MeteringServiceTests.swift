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

    func testVersionFourMigrationResetsVisualBoostsAndInstallsSignalDefaults() {
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
        XCTAssertEqual(defaults.integer(forKey: VUMeterDefaultsMigration.scaleVersionKey), 4)
        XCTAssertNil(defaults.object(forKey: "Orbisonic.vuMeterRendererVisualGainOffset"))
        XCTAssertNil(defaults.object(forKey: "Orbisonic.vuMeterNormalizesVisualEnergy"))
        XCTAssertEqual(defaults.double(forKey: VUMeterDefaultsMigration.referenceDbFSKey), -18, accuracy: 0.001)
        XCTAssertEqual(defaults.string(forKey: VUMeterDefaultsMigration.responseModeKey), VUMeterResponseMode.standard.rawValue)
        XCTAssertEqual(defaults.double(forKey: VUMeterDefaultsMigration.monitorTrimDbKey), 0, accuracy: 0.001)
        XCTAssertEqual(defaults.double(forKey: VUMeterDefaultsMigration.sonicSphereTrimDbKey), 0, accuracy: 0.001)
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

    private func amplitude(dbFS: Float) -> Float {
        powf(10, dbFS / 20)
    }
}
