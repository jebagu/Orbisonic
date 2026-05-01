import Foundation
import XCTest
@testable import AudioContracts

final class AudioContractsTests: XCTestCase {
    func testAudioSampleRateAcceptsFortyEightKilohertzAndRejectsInvalidRates() throws {
        let rate = try AudioSampleRate(hertz: 48_000)

        XCTAssertEqual(rate, .rate48000)
        XCTAssertThrowsError(try AudioSampleRate(hertz: -48_000))
        XCTAssertThrowsError(try AudioSampleRate(hertz: Double.nan))
    }

    func testDanteThirtyOneChannelEligibilityAllowsOnlyProductionRates() {
        for rate in [AudioSampleRate.rate44100, .rate48000, .rate88200, .rate96000] {
            XCTAssertTrue(rate.isDanteThirtyOneChannelProductionEligible, "\(rate.hertz)")
        }

        XCTAssertFalse(AudioSampleRate.rate176400.isDanteThirtyOneChannelProductionEligible)
        XCTAssertFalse(AudioSampleRate.rate192000.isDanteThirtyOneChannelProductionEligible)
    }

    func testAudioSessionFormatValidatesWhenDesktopAndDanteRatesMatch() {
        let session = makeSession()

        XCTAssertTrue(session.validationErrors().isEmpty)
        XCTAssertNoThrow(try session.validate())
    }

    func testAudioSessionFormatRejectsDesktopSampleRateMismatch() {
        let session = makeSession(
            desktop: DesktopOutputFormat(sampleRate: .rate44100)
        )

        XCTAssertTrue(session.validationErrors().contains {
            if case .sampleRateMismatch(_, _, let context) = $0 {
                return context == "desktop output"
            }
            return false
        })
    }

    func testAudioSessionFormatRejectsDanteSampleRateMismatch() {
        let session = makeSession(
            dante: DanteOutputFormat(physicalChannelCount: 31, sampleRate: .rate44100)
        )

        XCTAssertTrue(session.validationErrors().contains {
            if case .sampleRateMismatch(_, _, let context) = $0 {
                return context == "Dante output"
            }
            return false
        })
    }

    func testAudioSessionFormatRejectsDantePhysicalChannelCountBelowThirtyOne() {
        let session = makeSession(
            dante: DanteOutputFormat(physicalChannelCount: 30, sampleRate: .rate48000)
        )

        XCTAssertTrue(session.validationErrors().contains(.danteRouteInsufficientChannels(required: 31, actual: 30)))
    }

    func testAudioChannelLayoutDescriptorFallbacks() {
        XCTAssertEqual(AudioChannelLayoutDescriptor.fallbackLayout(channelCount: 1), .mono)
        XCTAssertEqual(AudioChannelLayoutDescriptor.fallbackLayout(channelCount: 2), .stereo)
        XCTAssertEqual(AudioChannelLayoutDescriptor.fallbackLayout(channelCount: 4), .quad)
        XCTAssertEqual(AudioChannelLayoutDescriptor.fallbackLayout(channelCount: 6), .surround51)
        XCTAssertEqual(AudioChannelLayoutDescriptor.fallbackLayout(channelCount: 31), .direct31)
        XCTAssertEqual(AudioChannelLayoutDescriptor.fallbackLayout(channelCount: 64).channelCount, 64)
        XCTAssertEqual(AudioChannelLayoutDescriptor.fallbackLayout(channelCount: 64).roles.first, .discrete(index: 0))
        XCTAssertEqual(AudioChannelLayoutDescriptor.fallbackLayout(channelCount: 64).roles.last, .discrete(index: 63))
    }

    func testSourceDescriptorRejectsMoreThanSixtyFourChannels() {
        let source = SourceDescriptor(
            id: "too-wide",
            kind: .localFile,
            sampleRate: .rate48000,
            channelCount: 65,
            layout: .discrete(count: 65)
        )

        XCTAssertTrue(source.validationErrors(sessionFormat: makeSession()).contains {
            if case .sourceChannelCountOutOfRange(let count, _, _) = $0 {
                return count == 65
            }
            return false
        })
    }

    func testSourceDescriptorRejectsSampleRateMismatchAgainstSessionFormat() {
        let source = SourceDescriptor(
            id: "mismatch",
            kind: .localFile,
            sampleRate: .rate44100,
            channelCount: 2,
            layout: .stereo
        )

        XCTAssertTrue(source.validationErrors(sessionFormat: makeSession()).contains {
            if case .sampleRateMismatch(_, _, let context) = $0 {
                return context == "source"
            }
            return false
        })
    }

    func testMeterSnapshotContainsValueMetersOnly() throws {
        let meter = ChannelMeter(rmsDBFS: -18, peakDBFS: -6, vuDB: 0, normalizedLevel: 0.5)
        let snapshot = MeterSnapshot(
            sessionVersion: 2,
            sourceID: "source",
            framePosition: 128,
            inputMeters: [meter],
            desktopMeters: [meter, meter],
            danteMeters: Array(repeating: meter, count: 31),
            timestampNanoseconds: 42
        )

        XCTAssertEqual(snapshot.inputMeters, [meter])
        XCTAssertEqual(snapshot.desktopMeters.count, 2)
        XCTAssertEqual(snapshot.danteMeters.count, 31)
        XCTAssertTrue(Mirror(reflecting: snapshot).children.allSatisfy { child in
            guard let label = child.label?.lowercased() else { return true }
            return !label.contains("buffer") && !label.contains("graph") && !label.contains("engine")
        })
    }

    func testConversionLedgerReportsInvalidIfProductionSampleRateConversionObserved() {
        let ledger = ConversionLedger(
            sessionSampleRate: .rate48000,
            sourceOriginalDescription: "44.1 kHz FLAC",
            sourceCanonicalDescription: "Float32 non-interleaved PCM",
            allowedConversions: [.codecDecodeToPCM, .integerPCMToFloat32],
            forbiddenConversionsObserved: [.productionSampleRateConversion],
            desktopOutputDescription: "48 kHz stereo",
            danteOutputDescription: "48 kHz 31-channel Dante"
        )

        XCTAssertTrue(ledger.containsProductionSampleRateConversion)
        XCTAssertEqual(ledger.validationStatus, .invalid([.productionSampleRateConversionForbidden]))
    }

    func testAudioContractsSourceDoesNotImportForbiddenAudioFrameworks() throws {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceURL = packageRoot.appendingPathComponent("Sources/AudioContracts/AudioContracts.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        for forbidden in ["AVFAudio", "AVFoundation", "CoreAudio", "AudioToolbox", "SwiftUI", "AppKit"] {
            XCTAssertFalse(source.contains("import \(forbidden)"), "AudioContracts imports \(forbidden)")
        }
    }

    private func makeSession(
        sampleRate: AudioSampleRate = .rate48000,
        dante: DanteOutputFormat? = nil,
        desktop: DesktopOutputFormat? = nil
    ) -> AudioSessionFormat {
        AudioSessionFormat(
            sampleRate: sampleRate,
            maxFramesPerBlock: 1_024,
            dante: dante ?? DanteOutputFormat(physicalChannelCount: 31, sampleRate: sampleRate),
            desktop: desktop ?? DesktopOutputFormat(sampleRate: sampleRate)
        )
    }
}
