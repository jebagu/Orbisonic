import AudioContracts
import AudioCore
import AudioImport
import Foundation
import XCTest

final class SourceAdapterTests: XCTestCase {
    func testRoonAdapterValidatesExpectedUIDOrRouteIdentityIfAvailable() throws {
        let route = liveRoute(
            uid: nil,
            name: "Orbisonic Roon Input",
            channels: 6,
            sampleRate: .defaultProduction
        )
        let adapter = try RoonSourceAdapter(route: route)

        try adapter.prepare(sessionFormat: sessionFormat())

        XCTAssertEqual(adapter.descriptor.kind, .roon)
        XCTAssertEqual(adapter.descriptor.channelCount, 6)
        XCTAssertTrue(adapter.latestStatusSnapshot().isPrepared)
    }

    func testRoonMetadataSampleRateMismatchIsDiagnosticAndDoesNotOverrideHALValidation() throws {
        let route = liveRoute(
            uid: PureAudioLoopbackUID.roon,
            name: "Orbisonic Roon Input",
            channels: 2,
            sampleRate: .defaultProduction
        )
        let adapter = try RoonSourceAdapter(route: route, metadataSampleRate: .rate44100)

        try adapter.prepare(sessionFormat: sessionFormat())

        let snapshot = adapter.latestStatusSnapshot()
        XCTAssertTrue(snapshot.isPrepared)
        XCTAssertTrue(snapshot.diagnosticMessages.joined(separator: " ").contains("metadata sample rate"))

        let mismatchedHAL = liveRoute(
            uid: PureAudioLoopbackUID.roon,
            name: "Orbisonic Roon Input",
            channels: 2,
            sampleRate: .rate44100
        )
        let rejected = try RoonSourceAdapter(route: mismatchedHAL, metadataSampleRate: .defaultProduction)
        XCTAssertThrowsError(try rejected.prepare(sessionFormat: sessionFormat())) { error in
            guard case AudioError.sampleRateMismatch = error else {
                return XCTFail("Expected HAL route sample-rate mismatch, got \(error).")
            }
        }
    }

    func testSpotifyAdapterForcesTwoChannels() throws {
        let route = liveRoute(
            uid: PureAudioLoopbackUID.spotify,
            name: "Orbisonic Spotify Input",
            channels: 8,
            sampleRate: .defaultProduction
        )
        let adapter = try SpotifySourceAdapter(route: route)

        try adapter.prepare(sessionFormat: sessionFormat())

        XCTAssertEqual(adapter.descriptor.kind, .spotify)
        XCTAssertEqual(adapter.descriptor.channelCount, 2)
        XCTAssertEqual(adapter.descriptor.layout, .stereo)
    }

    func testRoonStereoCapturePassesThroughToMonitorWithoutDownmix() throws {
        let route = liveRoute(
            uid: PureAudioLoopbackUID.roon,
            name: "Orbisonic Roon Input",
            channels: 2,
            sampleRate: .defaultProduction
        )
        let adapter = try RoonSourceAdapter(route: route)

        try adapter.prepare(sessionFormat: sessionFormat())
        let admission = adapter.monitorAdmission()

        XCTAssertEqual(adapter.descriptor.kind, .roon)
        XCTAssertEqual(adapter.descriptor.channelCount, 2)
        XCTAssertEqual(adapter.descriptor.layout, .stereo)
        XCTAssertEqual(admission.state, .stereoPassThrough)
        XCTAssertTrue(admission.canSubmitToStereoMonitor)
        XCTAssertEqual(admission.downmixOwner, .none)
    }

    func testRoonFiveOneCaptureIsDetectedAndMonitorDownmixIsBlockedWithoutExplicitOwner() throws {
        let route = liveRoute(
            uid: PureAudioLoopbackUID.roon,
            name: "Orbisonic Roon Input",
            channels: 6,
            sampleRate: .defaultProduction
        )
        let adapter = try RoonSourceAdapter(route: route)

        try adapter.prepare(sessionFormat: sessionFormat())
        let admission = adapter.monitorAdmission()

        XCTAssertEqual(adapter.descriptor.kind, .roon)
        XCTAssertEqual(adapter.descriptor.channelCount, 6)
        XCTAssertEqual(adapter.descriptor.layout, .surround51)
        XCTAssertEqual(admission.capturedChannelCount, 6)
        XCTAssertEqual(admission.capturedLayout, .surround51)
        XCTAssertEqual(admission.state, .blockedRequiresExplicitDownmixOwner)
        XCTAssertFalse(admission.canSubmitToStereoMonitor)
        XCTAssertEqual(admission.downmixOwner, .none)
        XCTAssertTrue(admission.diagnosticMessages.joined(separator: " ").contains("blocked"))
    }

    func testRoonFiveOneMonitorAdmissionRequiresExplicitOwner() throws {
        let adapter = try RoonSourceAdapter(
            route: liveRoute(
                uid: PureAudioLoopbackUID.roon,
                name: "Orbisonic Roon Input",
                channels: 6,
                sampleRate: .defaultProduction
            )
        )

        try adapter.prepare(sessionFormat: sessionFormat())
        let admission = adapter.monitorAdmission(explicitDownmixOwner: .roon)

        XCTAssertEqual(admission.state, .explicitDownmixAuthorized)
        XCTAssertTrue(admission.canSubmitToStereoMonitor)
        XCTAssertEqual(admission.downmixOwner, .roon)
    }

    func testRoonFiveOneDefaultPathStaysBlockedUnlessVlcLiveBridgeOwnerIsSelected() throws {
        let adapter = try RoonSourceAdapter(
            route: liveRoute(
                uid: PureAudioLoopbackUID.roon,
                name: "Orbisonic Roon Input",
                channels: 6,
                sampleRate: .defaultProduction
            )
        )

        try adapter.prepare(sessionFormat: sessionFormat())

        let defaultAdmission = adapter.monitorAdmission()
        XCTAssertEqual(defaultAdmission.state, .blockedRequiresExplicitDownmixOwner)
        XCTAssertFalse(defaultAdmission.canSubmitToStereoMonitor)
        XCTAssertEqual(defaultAdmission.downmixOwner, .none)

        let selectedAdmission = adapter.monitorAdmission(
            explicitDownmixOwner: .external("VLC live PCM bridge")
        )
        XCTAssertEqual(selectedAdmission.state, .explicitDownmixAuthorized)
        XCTAssertTrue(selectedAdmission.canSubmitToStereoMonitor)
        XCTAssertEqual(selectedAdmission.downmixOwner, .external("VLC live PCM bridge"))
    }

    func testSpotifyMonitorBoundaryReportsStereo() throws {
        let adapter = try SpotifySourceAdapter(
            route: liveRoute(
                uid: PureAudioLoopbackUID.spotify,
                name: "Orbisonic Spotify Input",
                channels: 8,
                sampleRate: .defaultProduction
            )
        )

        try adapter.prepare(sessionFormat: sessionFormat())
        let admission = adapter.monitorAdmission()

        XCTAssertEqual(admission.kind, .spotify)
        XCTAssertEqual(admission.capturedChannelCount, 2)
        XCTAssertEqual(admission.capturedLayout, .stereo)
        XCTAssertEqual(admission.state, .stereoPassThrough)
        XCTAssertTrue(admission.canSubmitToStereoMonitor)
    }

    func testLiveSourceFactoryDoesNotCarryStaleMetadataAcrossSourceModes() throws {
        let staleSpotifySelection = SourceSelection.source(
            SourceDescriptor(
                id: "stale-local-metadata",
                kind: .spotify,
                sampleRate: .rate44100,
                channelCount: 6,
                layout: .surround51,
                isLive: false,
                codecDescription: "stale local file metadata",
                originalPath: "old-local-5-1.wav"
            )
        )
        let spotify = try SourceAdapterFactory().makeAdapter(
            SourceAdapterFactoryRequest(
                selection: staleSpotifySelection,
                sessionFormat: sessionFormat(),
                liveRoutes: [
                    liveRoute(
                        uid: PureAudioLoopbackUID.spotify,
                        name: "Orbisonic Spotify Input",
                        channels: 8,
                        sampleRate: .defaultProduction
                    )
                ]
            )
        )

        XCTAssertEqual(spotify.descriptor.kind, .spotify)
        XCTAssertEqual(spotify.descriptor.sampleRate, .defaultProduction)
        XCTAssertEqual(spotify.descriptor.channelCount, 2)
        XCTAssertEqual(spotify.descriptor.layout, .stereo)
        XCTAssertTrue(spotify.descriptor.isLive)
        XCTAssertNil(spotify.descriptor.originalPath)

        let staleRoonSelection = SourceSelection.source(
            SourceDescriptor(
                id: "stale-spotify-metadata",
                kind: .roon,
                sampleRate: .rate44100,
                channelCount: 2,
                layout: .stereo,
                isLive: true,
                codecDescription: "stale spotify metadata"
            )
        )
        let roon = try SourceAdapterFactory().makeAdapter(
            SourceAdapterFactoryRequest(
                selection: staleRoonSelection,
                sessionFormat: sessionFormat(),
                liveRoutes: [
                    liveRoute(
                        uid: PureAudioLoopbackUID.roon,
                        name: "Orbisonic Roon Input",
                        channels: 6,
                        sampleRate: .defaultProduction
                    )
                ]
            )
        )

        XCTAssertEqual(roon.descriptor.kind, .roon)
        XCTAssertEqual(roon.descriptor.sampleRate, .defaultProduction)
        XCTAssertEqual(roon.descriptor.channelCount, 6)
        XCTAssertEqual(roon.descriptor.layout, .surround51)
        XCTAssertTrue(roon.descriptor.isLive)
    }

    func testAuxAdapterUsesDiscoveredChannelCountAndRejectsMoreThanSixtyFour() throws {
        let route = liveRoute(
            uid: PureAudioLoopbackUID.aux,
            name: "Orbisonic Aux Cable",
            channels: 12,
            sampleRate: .defaultProduction
        )
        let adapter = try AuxSourceAdapter(route: route)
        try adapter.prepare(sessionFormat: sessionFormat())
        XCTAssertEqual(adapter.descriptor.channelCount, 12)
        XCTAssertEqual(adapter.descriptor.layout, .surround714)

        let tooWideRoute = liveRoute(
            uid: PureAudioLoopbackUID.aux,
            name: "Orbisonic Aux Cable",
            channels: 65,
            sampleRate: .defaultProduction
        )
        let rejected = try AuxSourceAdapter(route: tooWideRoute)
        XCTAssertThrowsError(try rejected.prepare(sessionFormat: sessionFormat())) { error in
            XCTAssertEqual(
                error as? AudioError,
                .sourceChannelCountOutOfRange(count: 65, minimum: 1, maximum: 64)
            )
        }
    }

    func testLiveAdapterRejectsInputRouteSampleRateMismatch() throws {
        let route = liveRoute(
            uid: PureAudioLoopbackUID.aux,
            name: "Orbisonic Aux Cable",
            channels: 2,
            sampleRate: .rate44100
        )
        let adapter = try AuxSourceAdapter(route: route)

        XCTAssertThrowsError(try adapter.prepare(sessionFormat: sessionFormat())) { error in
            guard case AudioError.sampleRateMismatch = error else {
                return XCTFail("Expected source sample-rate mismatch, got \(error).")
            }
        }
    }

    func testLocalManagedAssetAdapterAcceptsMatchingSessionRate() throws {
        let asset = managedAsset(sampleRate: .defaultProduction, channelCount: 2, layout: .stereo)
        let block = try audioBlock(sampleRate: .defaultProduction, channelCount: 2, layout: .stereo, frameCount: 4)
        try block.setSample(0.5, channel: 0, frame: 0)
        let adapter = ManagedLocalAssetSourceAdapter(asset: asset, queuedBlocks: [block])
        let format = sessionFormat()

        try adapter.prepare(sessionFormat: format)
        try adapter.start()
        let bus = try CanonicalSourceBus(sessionFormat: format, source: adapter.descriptor, frameCapacity: 4)
        try adapter.renderIntoCanonicalBus(bus, frameCount: 4)

        let rendered = try bus.currentBlockForTestingCopy()
        XCTAssertEqual(rendered.sample(channel: 0, frame: 0), 0.5, accuracy: 0.000_001)
        XCTAssertEqual(rendered.sampleRate, .defaultProduction)
    }

    func testLocalUnmanagedMismatchedAssetIsRejectedForProduction() throws {
        let descriptor = SourceDescriptor(
            id: "unmanaged",
            kind: .localFile,
            sampleRate: .rate44100,
            channelCount: 2,
            layout: .stereo,
            originalPath: "unmanaged.wav"
        )
        let probe = LocalAssetProbeResult(
            path: "unmanaged.wav",
            sourceSampleRate: .rate44100,
            channelCount: 2,
            channelLayout: .stereo
        )

        XCTAssertThrowsError(
            try SourceAdapterFactory().makeAdapter(
                SourceAdapterFactoryRequest(
                    selection: .source(descriptor),
                    sessionFormat: sessionFormat(),
                    localAssetProbe: probe
                )
            )
        ) { error in
            XCTAssertEqual(error as? AudioError, .localAssetRequiresManagedImport(sourceID: "unmanaged.wav"))
        }
    }

    func testTestToneAdapterGeneratesAtSessionSampleRate() throws {
        let adapter = TestToneSourceAdapter(
            sessionSampleRate: .defaultProduction,
            mode: .desktopStereoID
        )
        let format = sessionFormat()

        try adapter.prepare(sessionFormat: format)
        try adapter.start()
        let bus = try CanonicalSourceBus(sessionFormat: format, source: adapter.descriptor, frameCapacity: 8)
        try adapter.renderIntoCanonicalBus(bus, frameCount: 8)

        let block = try bus.currentBlockForTestingCopy()
        XCTAssertEqual(block.sampleRate, .defaultProduction)
        XCTAssertEqual(block.channelCount, 2)
        XCTAssertNotEqual(block.sample(channel: 0, frame: 1), 0)
        XCTAssertEqual(block.sample(channel: 1, frame: 1), -block.sample(channel: 0, frame: 1), accuracy: 0.000_001)
    }

    func testOffSourceProducesSilence() throws {
        let adapter = try SourceAdapterFactory().makeAdapter(
            SourceAdapterFactoryRequest(selection: .off, sessionFormat: sessionFormat())
        )
        try adapter.start()
        let bus = try CanonicalSourceBus(sessionFormat: sessionFormat(), source: adapter.descriptor, frameCapacity: 4)

        try adapter.renderIntoCanonicalBus(bus, frameCount: 4)

        let block = try bus.currentBlockForTestingCopy()
        XCTAssertEqual(block.channelCount, 1)
        XCTAssertEqual(block.channelSamplesCopy(channel: 0), [0, 0, 0, 0])
        XCTAssertEqual(adapter.latestStatusSnapshot().kind, .off)
    }

    func testSourceAdapterFactoryReturnsTypedErrorsNotGraphObjects() throws {
        let descriptor = SourceDescriptor(
            id: "spotify",
            kind: .spotify,
            sampleRate: .defaultProduction,
            channelCount: 2,
            layout: .stereo
        )

        XCTAssertThrowsError(
            try SourceAdapterFactory().makeAdapter(
                SourceAdapterFactoryRequest(selection: .source(descriptor), sessionFormat: sessionFormat())
            )
        ) { error in
            XCTAssertEqual(error as? AudioError, .routeUnavailable(PureAudioLoopbackUID.spotify))
        }
    }

    func testSourceAdaptersDoNotExposeOutputRoutesOrGraphNodesInPublicAPI() throws {
        let source = try String(contentsOf: packageRoot().appendingPathComponent("Sources/AudioCore/SourceAdapters.swift"))
        let forbiddenSymbols = [
            "AVAudioEngine",
            "AVAudioNode",
            "AudioUnit",
            "AudioDeviceID",
            "AudioBufferList",
            "UnsafeMutablePointer",
            "RendererMatrix",
            "LiveAudioPipe",
            "RingBuffer",
            "OutputRouteDescriptor",
            "desktopRoute",
            "danteRoute"
        ]

        let violations = forbiddenSymbols.filter { source.contains($0) }
        XCTAssertTrue(violations.isEmpty, violations.joined(separator: "\n"))
    }

    private func sessionFormat(sampleRate: AudioSampleRate = .defaultProduction) -> AudioSessionFormat {
        AudioSessionFormat(
            sampleRate: sampleRate,
            maxFramesPerBlock: 512,
            dante: DanteOutputFormat(physicalChannelCount: 32, sampleRate: sampleRate),
            desktop: DesktopOutputFormat(sampleRate: sampleRate)
        )
    }

    private func liveRoute(
        uid: String?,
        name: String,
        channels: Int,
        sampleRate: AudioSampleRate,
        isAvailable: Bool = true
    ) -> LiveInputRouteDescriptor {
        LiveInputRouteDescriptor(
            id: uid ?? name,
            uid: uid,
            name: name,
            manufacturer: "Orbisonic",
            transportName: "Virtual",
            inputChannelCount: channels,
            nominalSampleRate: sampleRate,
            isAvailable: isAvailable
        )
    }

    private func managedAsset(
        sampleRate: AudioSampleRate,
        channelCount: Int,
        layout: AudioChannelLayoutDescriptor
    ) -> ManagedAssetDescriptor {
        ManagedAssetDescriptor(
            id: "managed",
            originalPath: "original.wav",
            managedPath: "managed.caf",
            originalSampleRate: sampleRate,
            managedSampleRate: sampleRate,
            channelCount: channelCount,
            layout: layout,
            conversionLedger: ConversionLedger(
                sessionSampleRate: sampleRate,
                sourceOriginalDescription: "test original",
                sourceCanonicalDescription: "test managed",
                allowedConversions: [.codecDecodeToPCM, .integerPCMToFloat32, .interleavedToDeinterleaved],
                forbiddenConversionsObserved: [],
                desktopOutputDescription: "desktop",
                danteOutputDescription: "dante"
            )
        )
    }

    private func audioBlock(
        sampleRate: AudioSampleRate,
        channelCount: Int,
        layout: AudioChannelLayoutDescriptor,
        frameCount: Int
    ) throws -> CanonicalAudioBlock {
        try CanonicalAudioBlock(
            format: AudioBlockFormat(
                sampleRate: sampleRate,
                channelCount: channelCount,
                frameCount: frameCount,
                layout: layout
            )
        )
    }

    private func packageRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
