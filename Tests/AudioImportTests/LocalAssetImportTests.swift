import AudioContracts
import AudioImport
import AVFoundation
import CoreAudioTypes
import XCTest

final class LocalAssetImportTests: XCTestCase {
    func testFortyEightKilohertzFileIsProductionReadyInFortyEightKilohertzSession() throws {
        let probe = probeResult(sampleRate: .rate48000)

        XCTAssertTrue(probe.isProductionReady(for: sessionFormat(rate: .rate48000)))
        XCTAssertEqual(
            probe.readiness(for: sessionFormat(rate: .rate48000), routeCapabilities: []),
            .productionReady
        )
    }

    func testFortyFourOneFileRequiresOfflineImportInRunningFortyEightKilohertzProductionSession() {
        let readiness = probeResult(sampleRate: .rate44100).readiness(
            for: sessionFormat(rate: .rate48000),
            routeCapabilities: [danteCapability(rate: .rate44100, channels: 32)],
            isSessionRunning: true
        )

        guard case .requiresOfflineImport(let reason, let targetSampleRate) = readiness else {
            return XCTFail("Expected offline import requirement, got \(readiness).")
        }

        XCTAssertEqual(targetSampleRate, .rate48000)
        XCTAssertTrue(reason.contains("This file is 44.1 kHz"))
        XCTAssertTrue(reason.contains("Current Orbisonic Dante session is 48 kHz"))
    }

    func testFortyFourOneFileCanRestartStoppedSessionOnlyWhenDanteSupportsFileRate() {
        let supported = probeResult(sampleRate: .rate44100).readiness(
            for: sessionFormat(rate: .rate48000),
            routeCapabilities: [danteCapability(rate: .rate44100, channels: 32)],
            isSessionRunning: false
        )
        let unsupported = probeResult(sampleRate: .rate44100).readiness(
            for: sessionFormat(rate: .rate48000),
            routeCapabilities: [danteCapability(rate: .rate48000, channels: 32)],
            isSessionRunning: false
        )

        guard case .canRestartStoppedSessionAtFileRate(_, let fileSampleRate) = supported else {
            return XCTFail("Expected stopped-session restart option, got \(supported).")
        }

        XCTAssertEqual(fileSampleRate, .rate44100)
        guard case .requiresOfflineImport(_, let targetSampleRate) = unsupported else {
            return XCTFail("Expected offline import when Dante cannot run the file rate, got \(unsupported).")
        }
        XCTAssertEqual(targetSampleRate, .rate48000)
    }

    func testOneNinetyTwoKilohertzFileCannotRestartThirtyOneChannelDVSProductionSession() {
        let readiness = probeResult(sampleRate: .rate192000).readiness(
            for: sessionFormat(rate: .rate48000),
            routeCapabilities: [danteCapability(rate: .rate192000, channels: 32)],
            isSessionRunning: false
        )

        if case .canRestartStoppedSessionAtFileRate = readiness {
            XCTFail("192 kHz DVS route must not be offered as a 31-channel production restart.")
        }
    }

    func testProductionGateRejectsHiddenSampleRateConversion() {
        XCTAssertThrowsError(
            try ProductionLocalAssetGate().validateProductionAdmission(
                probeResult(sampleRate: .rate44100),
                sessionFormat: sessionFormat(rate: .rate48000)
            )
        ) { error in
            XCTAssertEqual(
                error as? AudioError,
                .localAssetRequiresManagedImport(sourceID: "fixture.wav")
            )
        }
    }

    func testManagedImportWritesCAFAndRecordsOfflineSampleRateConversion() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let sourceURL = directory.appendingPathComponent("source-44100.wav")
        let managedURL = directory.appendingPathComponent("managed-48000.caf")
        try writeSilentAudioFile(to: sourceURL, sampleRate: 44_100, channels: 2, frames: 4_410)

        let descriptor = try ManagedAssetImporter().importAsset(
            originalPath: sourceURL.path,
            managedPath: managedURL.path,
            managedAssetID: "managed-source",
            targetSessionFormat: sessionFormat(rate: .rate48000),
            declaredSourceSampleRate: .rate44100,
            declaredSourceChannelCount: 2,
            declaredSourceLayout: .stereo
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: managedURL.path))
        XCTAssertEqual(descriptor.originalSampleRate, .rate44100)
        XCTAssertEqual(descriptor.managedSampleRate, .rate48000)
        XCTAssertEqual(descriptor.sampleRate, .rate48000)
        XCTAssertEqual(descriptor.channelCount, 2)
        XCTAssertEqual(descriptor.layout.channelCount, 2)
        XCTAssertTrue(descriptor.conversionLedger.allowedConversions.contains(.offlineManagedSampleRateConversion))
        XCTAssertEqual(descriptor.conversionLedger.validationStatus, .valid)

        let importedFile = try AVAudioFile(forReading: managedURL)
        XCTAssertEqual(importedFile.processingFormat.sampleRate, 48_000, accuracy: 1)
        XCTAssertEqual(importedFile.processingFormat.channelCount, 2)
    }

    func testManagedImportPreservesLayoutChannelCount() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let sourceURL = directory.appendingPathComponent("quad-48000.wav")
        let managedURL = directory.appendingPathComponent("quad-48000.caf")
        try writeSilentAudioFile(to: sourceURL, sampleRate: 48_000, channels: 4, frames: 4_800)

        let descriptor = try ManagedAssetImporter().importAsset(
            originalPath: sourceURL.path,
            managedPath: managedURL.path,
            managedAssetID: "managed-quad",
            targetSessionFormat: sessionFormat(rate: .rate48000),
            declaredSourceSampleRate: .rate48000,
            declaredSourceChannelCount: 4,
            declaredSourceLayout: .quad
        )

        XCTAssertEqual(descriptor.channelCount, 4)
        XCTAssertEqual(descriptor.layout, .quad)
        XCTAssertEqual(descriptor.layout.channelCount, descriptor.channelCount)
        XCTAssertFalse(descriptor.conversionLedger.allowedConversions.contains(.offlineManagedSampleRateConversion))
    }

    private func probeResult(
        sampleRate: AudioSampleRate,
        channelCount: Int = 2,
        layout: AudioChannelLayoutDescriptor = .stereo
    ) -> LocalAssetProbeResult {
        LocalAssetProbeResult(
            path: "fixture.wav",
            durationFrames: 48_000,
            durationSeconds: 1,
            sourceSampleRate: sampleRate,
            channelCount: channelCount,
            codecDescription: "PCM",
            channelLayout: layout,
            containerDescription: "WAV",
            estimatedDecodedBytes: 48_000 * Int64(channelCount) * Int64(MemoryLayout<Float>.size)
        )
    }

    private func sessionFormat(rate: AudioSampleRate) -> AudioSessionFormat {
        AudioSessionFormat(
            sampleRate: rate,
            maxFramesPerBlock: 512,
            dante: DanteOutputFormat(physicalChannelCount: 32, sampleRate: rate),
            desktop: DesktopOutputFormat(sampleRate: rate)
        )
    }

    private func danteCapability(rate: AudioSampleRate, channels: Int) -> DanteRouteCapability {
        let route = OutputRouteDescriptor(
            id: "dvs",
            uid: "dvs",
            name: "Dante Virtual Soundcard",
            manufacturer: "Audinate",
            transportName: "Virtual",
            outputChannelCount: channels,
            nominalSampleRate: rate,
            isAvailable: true,
            risk: .preferredDante
        )
        return DanteRouteCapability(
            route: route,
            supportedSampleRates: [rate],
            currentNominalSampleRate: rate,
            outputChannelCount: channels
        )
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("orbisonic-audio-import-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func writeSilentAudioFile(
        to url: URL,
        sampleRate: Double,
        channels: AVAudioChannelCount,
        frames: AVAudioFrameCount
    ) throws {
        let format: AVAudioFormat?
        if channels == 4, let layout = AVAudioChannelLayout(layoutTag: kAudioChannelLayoutTag_Quadraphonic) {
            format = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: sampleRate,
                interleaved: false,
                channelLayout: layout
            )
        } else {
            format = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: sampleRate,
                channels: channels,
                interleaved: false
            )
        }

        guard let format,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)
        else {
            XCTFail("Could not create test audio format")
            return
        }

        buffer.frameLength = frames
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
    }
}
