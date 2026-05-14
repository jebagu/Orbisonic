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

    func testStereoMonitorBlockRequiresFinishedStereoFloat32PCM() throws {
        let stereo = AudioBlockContract(
            sourceID: "local-file",
            generation: 2,
            sampleRate: .rate48000,
            frameStart: 0,
            frameCount: 512,
            channelCount: 2,
            processingFormat: .float32InterleavedPCM,
            layout: SourceLayout(descriptor: .stereo, authority: .containerMetadata)
        )

        XCTAssertNoThrow(try StereoMonitorBlock(contract: stereo))

        let surround = AudioBlockContract(
            sourceID: "local-file",
            generation: 2,
            sampleRate: .rate48000,
            frameStart: 0,
            frameCount: 512,
            channelCount: 6,
            processingFormat: .float32InterleavedPCM,
            layout: SourceLayout(descriptor: .surround51, authority: .containerMetadata)
        )

        XCTAssertThrowsError(try StereoMonitorBlock(contract: surround))
    }

    func testCanonicalSourceBlockRequiresPlanarProductionContract() throws {
        let block = AudioBlockContract(
            sourceID: "roon-capture",
            generation: 8,
            sampleRate: .rate48000,
            frameStart: 1_024,
            frameCount: 256,
            channelCount: 6,
            processingFormat: .float32NonInterleavedPCM,
            layout: SourceLayout(descriptor: .surround51, authority: .liveCaptureContract, authorityID: "Orbisonic Roon Input")
        )

        let canonical = try CanonicalSourceBlock(contract: block)

        XCTAssertEqual(canonical.sourceID, "roon-capture")
        XCTAssertEqual(canonical.channelCount, 6)
        XCTAssertEqual(canonical.layout.authority, .liveCaptureContract)
    }

    func testRenderedSphereBlockRequiresOutputMapAndSphereProfile() throws {
        let block = AudioBlockContract(
            sourceID: "sphere-bed",
            generation: 4,
            sampleRate: .rate48000,
            frameStart: 0,
            frameCount: 128,
            channelCount: 31,
            processingFormat: .float32NonInterleavedPCM,
            layout: SourceLayout(descriptor: .direct31, authority: .rendererOutputMap, authorityID: "dante-31")
        )

        let rendered = try RenderedSphereBlock(
            contract: block,
            outputMapID: "dante-31",
            sphereProfileID: "sonic-sphere-31"
        )

        XCTAssertEqual(rendered.outputMapID, "dante-31")
        XCTAssertThrowsError(try RenderedSphereBlock(contract: block, outputMapID: "", sphereProfileID: "sonic-sphere-31"))
    }

    func testAudioConversionLedgerRepresentsRequiredOrbisonic2Paths() {
        let source51 = AudioFormatSummary(
            sampleRate: .rate48000,
            channelCount: 6,
            sampleFormat: "LPCM",
            layoutName: "5.1 Surround"
        )
        let stereo = AudioFormatSummary(
            sampleRate: .rate48000,
            channelCount: 2,
            sampleFormat: "Float32",
            layoutName: "Stereo"
        )
        let sphere = AudioFormatSummary(
            sampleRate: .rate48000,
            channelCount: 31,
            sampleFormat: "Float32",
            layoutName: "Direct 30.1"
        )
        let dante = AudioFormatSummary(
            sampleRate: .rate48000,
            channelCount: 31,
            sampleFormat: "PCM 24-bit",
            layoutName: "Dante 31"
        )

        let localMonitor = AudioConversionLedger.localVLCMonitor(
            sessionID: "s1",
            sourceID: "local",
            source: source51,
            monitor: stereo
        )
        XCTAssertTrue(localMonitor.contains(stage: .decode, owner: .vlc))
        XCTAssertTrue(localMonitor.contains(stage: .downmix, owner: .vlc))
        XCTAssertTrue(localMonitor.contains(stage: .format, owner: .orbisonic))
        XCTAssertTrue(localMonitor.contains(stage: .routeValidation, owner: .orbisonic))
        XCTAssertFalse(localMonitor.hasHiddenConversionRisk)

        let roon = AudioConversionLedger.roonCapture(
            sessionID: "s2",
            sourceID: "roon",
            captured: source51
        )
        XCTAssertTrue(roon.contains(stage: .capture, owner: .roon))

        let production = AudioConversionLedger.danteProduction(
            sessionID: "s3",
            sourceID: "local-prod",
            source: source51,
            rendered: sphere,
            output: dante,
            srcOccurred: true
        )
        XCTAssertTrue(production.contains(stage: .decode, owner: .orbisonic))
        XCTAssertTrue(production.contains(stage: .sampleRateConversion, owner: .sourceRateConverter))
        XCTAssertTrue(production.contains(stage: .render, owner: .sonicSphereRenderer))
        XCTAssertTrue(production.contains(stage: .format, owner: .danteOutputFormatter))
        XCTAssertTrue(production.contains(stage: .routeValidation, owner: .productionOutputSession))

        let pure = AudioConversionLedger.pureSphericalDirect(
            sessionID: "s4",
            sourceID: "pure",
            source: sphere,
            output: dante
        )
        XCTAssertTrue(pure.contains(stage: .validation, owner: .pureSphericalLosslessValidator))
        XCTAssertTrue(pure.contains(stage: .directRead, owner: .pureSphericalLosslessReader))
        XCTAssertTrue(pure.contains(stage: .routeValidation, owner: .productionOutputSession))
        XCTAssertFalse(pure.contains(stage: .render, owner: .sonicSphereRenderer))
    }

    func testPureSphericalLosslessBadgeTextIsRestrictedToApprovedLabels() {
        XCTAssertNil(PureSphericalLosslessState.none.badgeText)
        XCTAssertNil(PureSphericalLosslessState.candidate.badgeText)
        XCTAssertNil(PureSphericalLosslessState.invalid(reason: "metadata missing").badgeText)
        XCTAssertEqual(PureSphericalLosslessState.validForCurrentSphere.badgeText, "Pure Spherical Lossless")
        XCTAssertEqual(PureSphericalLosslessState.validForDifferentSphere.badgeText, "Pure Spherical Lossless, different sphere")
        XCTAssertEqual(PureSphericalLosslessState.routeNotReady.badgeText, "Pure Spherical Lossless, route not ready")
    }

    func testPlaybackDiagnosticSnapshotCarriesRequiredMinimumFacts() {
        let source = AudioFormatSummary(
            sampleRate: .rate48000,
            channelCount: 6,
            sampleFormat: "Float32",
            layoutName: "5.1 Surround"
        )
        let output = AudioFormatSummary(
            sampleRate: .rate48000,
            channelCount: 31,
            sampleFormat: "PCM 24-bit",
            layoutName: "Dante 31"
        )
        let ledger = AudioConversionLedger.danteProduction(
            sessionID: "diagnostic-session",
            sourceID: "source",
            source: source,
            rendered: output,
            output: output,
            srcOccurred: false
        )

        let snapshot = PlaybackDiagnosticSnapshot(
            sessionID: "diagnostic-session",
            sourceID: "source",
            sourceKind: .localFile,
            sourceSampleRate: .rate48000,
            sourceChannelCount: 6,
            decodeOwner: .orbisonic,
            rendererOwner: .sonicSphereRenderer,
            outputFormatterOwner: .danteOutputFormatter,
            requestedOutputFormat: output,
            actualOutputFormat: output,
            routeChannelCount: 31,
            underflowCount: -1,
            overflowCount: 2,
            staleGenerationRejectedCount: 3,
            pureSphericalLosslessState: .none,
            conversionLedger: ledger
        )

        XCTAssertEqual(snapshot.sourceSampleRate, .rate48000)
        XCTAssertEqual(snapshot.sourceChannelCount, 6)
        XCTAssertEqual(snapshot.rendererOwner, .sonicSphereRenderer)
        XCTAssertEqual(snapshot.outputFormatterOwner, .danteOutputFormatter)
        XCTAssertEqual(snapshot.routeChannelCount, 31)
        XCTAssertEqual(snapshot.underflowCount, 0)
        XCTAssertEqual(snapshot.overflowCount, 2)
        XCTAssertEqual(snapshot.staleGenerationRejectedCount, 3)
        XCTAssertTrue(snapshot.conversionLedger.contains(stage: .render, owner: .sonicSphereRenderer))
        XCTAssertTrue(snapshot.completenessIssues(requiredStages: [.decode, .render, .format, .routeValidation]).isEmpty)
    }

    func testPlaybackDiagnosticCompletenessReportsMissingLedgerStagesAndOwnerMismatches() {
        let source = AudioFormatSummary(
            sampleRate: .rate48000,
            channelCount: 2,
            sampleFormat: "Float32",
            layoutName: "Stereo"
        )
        let ledger = AudioConversionLedger(
            sessionID: "bad-session",
            sourceID: "source",
            sourceKind: .spotify,
            entries: [
                AudioConversionLedgerEntry(
                    stage: .capture,
                    owner: .spotify,
                    output: source,
                    isExplicit: true
                )
            ]
        )
        let snapshot = PlaybackDiagnosticSnapshot(
            sessionID: "bad-session",
            sourceID: "source",
            sourceKind: .spotify,
            sourceSampleRate: .rate48000,
            sourceChannelCount: 2,
            decodeOwner: .none,
            requestedOutputFormat: source,
            actualOutputFormat: source,
            routeChannelCount: 2,
            conversionLedger: ledger
        )

        let issues = snapshot.completenessIssues(requiredStages: [.capture, .format])

        XCTAssertTrue(issues.contains(.missingLedgerStage(.format)))
        XCTAssertTrue(issues.contains(.ownerMismatch(stage: .capture, snapshotOwner: .none, ledgerOwners: [.spotify])))
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
