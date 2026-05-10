import AudioContracts
import AudioCore
import XCTest
@testable import Orbisonic

final class OrbisonicAudioCoordinator2Tests: XCTestCase {
    func testLocalMonitorSelectsFutureVLCPath() throws {
        var coordinator = OrbisonicAudioCoordinator2()

        let prepared = try coordinator.prepareSource(
            OrbisonicSourcePreparationRequest(
                selection: .source(localFileDescriptor(channelCount: 6, layout: .surround51)),
                product: .monitor
            )
        )

        XCTAssertEqual(prepared.path, .localVLCStereoMonitor)
        XCTAssertEqual(prepared.diagnostics.decodeOwner, .vlc)
        XCTAssertEqual(prepared.diagnostics.downmixOwner, .vlc)
        XCTAssertTrue(prepared.diagnostics.conversionLedger.contains(stage: .downmix, owner: .vlc))
        XCTAssertFalse(prepared.diagnostics.conversionLedger.contains(stage: .render, owner: .sonicSphereRenderer))
    }

    func testLocalProductionSelectsSourcePreservingPathAndDoesNotUseVLCMonitorCallback() throws {
        var coordinator = OrbisonicAudioCoordinator2()

        let prepared = try coordinator.prepareSource(
            OrbisonicSourcePreparationRequest(
                selection: .source(localFileDescriptor(channelCount: 6, layout: .surround51)),
                product: .production
            )
        )

        XCTAssertEqual(prepared.path, .localSourcePreservingProduction)
        XCTAssertEqual(prepared.diagnostics.decodeOwner, .orbisonic)
        XCTAssertEqual(prepared.diagnostics.downmixOwner, .none)
        XCTAssertEqual(prepared.diagnostics.rendererOwner, .sonicSphereRenderer)
        XCTAssertFalse(prepared.diagnostics.conversionLedger.contains(stage: .downmix, owner: .vlc))
        XCTAssertTrue(prepared.diagnostics.conversionLedger.contains(stage: .render, owner: .sonicSphereRenderer))
    }

    func testRoonSelectsLivePcmCapturePath() throws {
        var coordinator = OrbisonicAudioCoordinator2()

        let prepared = try coordinator.prepareSource(
            OrbisonicSourcePreparationRequest(
                selection: .source(liveDescriptor(kind: .roon, channelCount: 6, layout: .surround51)),
                product: .monitor
            )
        )

        XCTAssertEqual(prepared.path, .roonLivePcmCapture)
        XCTAssertEqual(prepared.diagnostics.decodeOwner, .roon)
        XCTAssertEqual(prepared.diagnostics.downmixOwner, .none)
        XCTAssertTrue(prepared.diagnostics.conversionLedger.contains(stage: .capture, owner: .roon))
    }

    func testSpotifySelectsStereoSourcePath() throws {
        var coordinator = OrbisonicAudioCoordinator2()

        let prepared = try coordinator.prepareSource(
            OrbisonicSourcePreparationRequest(
                selection: .source(liveDescriptor(kind: .spotify, channelCount: 2, layout: .stereo)),
                product: .monitor
            )
        )

        XCTAssertEqual(prepared.path, .spotifyStereoSource)
        XCTAssertEqual(prepared.diagnostics.decodeOwner, .spotify)
        XCTAssertEqual(prepared.diagnostics.sourceChannelCount, 2)
        XCTAssertTrue(prepared.diagnostics.conversionLedger.contains(stage: .capture, owner: .spotify))
    }

    func testPureSphericalCandidateSelectsValidatorPath() throws {
        var coordinator = OrbisonicAudioCoordinator2()

        let prepared = try coordinator.prepareSource(
            OrbisonicSourcePreparationRequest(
                selection: .source(localFileDescriptor(channelCount: 31, layout: .direct31)),
                product: .production,
                pureSphericalLosslessState: .candidate
            )
        )

        XCTAssertEqual(prepared.path, .pureSphericalLosslessValidator)
        XCTAssertEqual(prepared.diagnostics.pureSphericalLosslessState, .candidate)
        XCTAssertEqual(prepared.diagnostics.decodeOwner, .none)
        XCTAssertEqual(prepared.diagnostics.rendererOwner, .none)
        XCTAssertFalse(prepared.diagnostics.conversionLedger.contains(stage: .render, owner: .sonicSphereRenderer))
        XCTAssertTrue(prepared.diagnostics.conversionLedger.contains(stage: .validation, owner: .pureSphericalLosslessValidator))
    }

    func testExistingUIFacadeMapsSourceModeSelectionIntoCoordinator() throws {
        var facade = ExistingOrbisonicUIFacade()

        let prepared = try facade.selectSource(.roon)

        XCTAssertEqual(prepared.path, .roonLivePcmCapture)
        XCTAssertEqual(facade.observeNowPlayingState().sourceMode, .roon)
        XCTAssertEqual(facade.observeNowPlayingState().preparedPath, .roonLivePcmCapture)
        XCTAssertEqual(facade.observeDiagnosticsState().snapshot?.sourceKind, .roon)
    }

    func testExistingUIFacadeMapsLocalFileIntoMonitorAndPureSphericalProductionPaths() throws {
        let url = URL(fileURLWithPath: "/tmp/test-pure-sphere.bw64")
        var facade = ExistingOrbisonicUIFacade()

        let monitor = try facade.selectLocalFile(url)
        XCTAssertEqual(monitor.path, .localVLCStereoMonitor)

        let pure = try facade.selectLocalFile(
            url,
            product: .production,
            pureSphericalLosslessState: .validForCurrentSphere
        )
        XCTAssertEqual(pure.path, .pureSphericalLosslessValidator)
        XCTAssertEqual(facade.observePureSphericalBadge().badgeText, "Pure Spherical Lossless")
    }

    func testDiagnosticsLedgerCompletenessAcrossImplementedPlaybackPaths() throws {
        var coordinator = OrbisonicAudioCoordinator2()

        let localMonitor = try coordinator.prepareSource(
            OrbisonicSourcePreparationRequest(
                selection: .source(localFileDescriptor(channelCount: 6, layout: .surround51)),
                product: .monitor
            )
        )
        assertNoDiagnosticIssues(
            localMonitor,
            requiredStages: [.decode, .downmix, .format, .routeValidation]
        )

        let localProduction = try coordinator.prepareSource(
            OrbisonicSourcePreparationRequest(
                selection: .source(localFileDescriptor(channelCount: 6, layout: .surround51, sampleRate: .rate44100)),
                product: .production
            )
        )
        assertNoDiagnosticIssues(
            localProduction,
            requiredStages: [.decode, .sampleRateConversion, .render, .format, .routeValidation]
        )

        let roonProduction = try coordinator.prepareSource(
            OrbisonicSourcePreparationRequest(
                selection: .source(liveDescriptor(kind: .roon, channelCount: 6, layout: .surround51)),
                product: .production
            )
        )
        assertNoDiagnosticIssues(
            roonProduction,
            requiredStages: [.capture, .render, .format, .routeValidation]
        )

        let spotifyProduction = try coordinator.prepareSource(
            OrbisonicSourcePreparationRequest(
                selection: .source(liveDescriptor(kind: .spotify, channelCount: 2, layout: .stereo)),
                product: .production
            )
        )
        assertNoDiagnosticIssues(
            spotifyProduction,
            requiredStages: [.capture, .render, .format, .routeValidation]
        )

        let pureProduction = try coordinator.prepareSource(
            OrbisonicSourcePreparationRequest(
                selection: .source(localFileDescriptor(channelCount: 31, layout: .direct31)),
                product: .production,
                pureSphericalLosslessState: .validForCurrentSphere
            )
        )
        assertNoDiagnosticIssues(
            pureProduction,
            requiredStages: [.validation, .directRead, .format, .routeValidation]
        )
    }

    func testExistingDiagnosticsStateSurfacesLedgerFailures() {
        let emptyLedger = AudioConversionLedger(
            sessionID: "broken",
            sourceID: "spotify",
            sourceKind: .spotify,
            entries: []
        )
        let snapshot = PlaybackDiagnosticSnapshot(
            sessionID: "broken",
            sourceID: "spotify",
            sourceKind: .spotify,
            sourceSampleRate: nil,
            sourceChannelCount: nil,
            requestedOutputFormat: nil,
            actualOutputFormat: nil,
            routeChannelCount: nil,
            conversionLedger: emptyLedger
        )

        let state = ExistingDiagnosticsState(snapshot: snapshot)

        XCTAssertFalse(state.failureMessages.isEmpty)
        XCTAssertTrue(state.statusRows.contains { $0.isFailure && $0.value.contains("No conversion ledger") })
    }

    private func assertNoDiagnosticIssues(
        _ prepared: PreparedSource,
        requiredStages: [AudioConversionStage],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let issues = prepared.diagnostics.completenessIssues(requiredStages: requiredStages)
        XCTAssertTrue(
            issues.isEmpty,
            issues.map(\.diagnosticMessage).joined(separator: "\n"),
            file: file,
            line: line
        )
    }

    private func localFileDescriptor(
        channelCount: Int,
        layout: AudioChannelLayoutDescriptor,
        sampleRate: AudioSampleRate = .rate48000
    ) -> SourceDescriptor {
        SourceDescriptor(
            id: "local-\(channelCount)",
            kind: .localFile,
            sampleRate: sampleRate,
            channelCount: channelCount,
            layout: layout,
            isLive: false,
            codecDescription: "LPCM",
            originalPath: "/tmp/local-\(channelCount).wav"
        )
    }

    private func liveDescriptor(
        kind: SourceKind,
        channelCount: Int,
        layout: AudioChannelLayoutDescriptor
    ) -> SourceDescriptor {
        SourceDescriptor(
            id: "\(kind.rawValue)-live",
            kind: kind,
            sampleRate: .rate48000,
            channelCount: channelCount,
            layout: layout,
            isLive: true
        )
    }
}
