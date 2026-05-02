import CoreAudio
import XCTest
@testable import Orbisonic

final class LoopbackSourceSupportTests: XCTestCase {
    func testMusicInputsExposeExactlyOffRoonSpotifyAuxCableAndLocalFiles() {
        XCTAssertEqual(SourceMode.musicInputs, [.off, .roon, .spotify, .aux, .filePlayback])
        XCTAssertEqual(SourceMode.musicInputs.map(\.rawValue), ["Off", "Roon", "Spotify", "Aux Cable", "Local Files"])
        XCTAssertEqual(SourceMode.musicInputs.map(\.displayName), ["Off", "Roon", "Spotify", "Aux Cable", "Local Music"])
        XCTAssertTrue(SourceMode.musicInputs.allSatisfy(\.isUserFacingMusicInput))
        XCTAssertFalse(SourceMode.musicInputs.contains(.testTone))
    }

    func testLiveSourceLabelsUseDedicatedSourceNames() {
        XCTAssertEqual(SourceMode.spotify.monitorActionLabel, "Listen to Spotify")
        XCTAssertEqual(SourceMode.spotify.muteActionLabel, "Mute Spotify")
        XCTAssertEqual(SourceMode.spotify.mutedActionLabel, "Resume Spotify")
        XCTAssertEqual(SourceMode.spotify.stopMonitorLabel, "Stop")
        XCTAssertEqual(SourceMode.aux.monitorActionLabel, "Listen to Aux Cable")
        XCTAssertEqual(SourceMode.aux.muteActionLabel, "Mute Aux Cable")
        XCTAssertEqual(SourceMode.aux.mutedActionLabel, "Resume Aux Cable")
    }

    func testLiveSourcesMapToStableOrbisonicLoopbackUIDs() {
        XCTAssertEqual(SourceMode.roon.expectedLoopback?.deviceUID, "audio.orbisonic.rooninput.device")
        XCTAssertEqual(SourceMode.spotify.expectedLoopback?.deviceUID, "audio.orbisonic.spotifyinput.device")
        XCTAssertEqual(SourceMode.aux.expectedLoopback?.deviceUID, "audio.orbisonic.auxcable.device")
        XCTAssertNil(SourceMode.off.expectedLoopback)
        XCTAssertNil(SourceMode.filePlayback.expectedLoopback)
        XCTAssertNil(SourceMode.testTone.expectedLoopback)
    }

    func testLiveSourcesDoNotOwnPlaybackTransport() {
        XCTAssertFalse(SourceMode.roon.ownsTransport)
        XCTAssertFalse(SourceMode.spotify.ownsTransport)
        XCTAssertFalse(SourceMode.aux.ownsTransport)
        XCTAssertTrue(SourceMode.filePlayback.ownsTransport)
    }

    func testLiveSourcesStartListeningWhenSelected() {
        XCTAssertTrue(SourceMode.roon.startsLiveListeningOnSelection)
        XCTAssertTrue(SourceMode.spotify.startsLiveListeningOnSelection)
        XCTAssertTrue(SourceMode.aux.startsLiveListeningOnSelection)
        XCTAssertFalse(SourceMode.off.startsLiveListeningOnSelection)
        XCTAssertFalse(SourceMode.filePlayback.startsLiveListeningOnSelection)
        XCTAssertFalse(SourceMode.testTone.startsLiveListeningOnSelection)
    }

    func testInputRouteClassifiesOrbisonicLoopbacksByUID() {
        let roon = inputRoute(
            uid: OrbisonicLoopbackDevice.roonInput.deviceUID,
            name: "User Renamed Device",
            manufacturer: "Orbisonic"
        )
        let spotify = inputRoute(
            uid: OrbisonicLoopbackDevice.spotifyInput.deviceUID,
            name: "Renamed Spotify Input",
            manufacturer: "Orbisonic"
        )
        let aux = inputRoute(
            uid: OrbisonicLoopbackDevice.auxCable.deviceUID,
            name: "Another User Name",
            manufacturer: "Orbisonic"
        )

        XCTAssertEqual(roon.role, .roonLoopback)
        XCTAssertTrue(roon.isRoonLoopback)
        XCTAssertEqual(spotify.role, .spotifyLoopback)
        XCTAssertTrue(spotify.isSpotifyLoopback)
        XCTAssertEqual(aux.role, .auxLoopback)
        XCTAssertTrue(aux.isAuxLoopback)
    }

    func testLiveSourceModesRejectOtherOrbisonicLoopbacks() {
        let roon = inputRoute(
            uid: OrbisonicLoopbackDevice.roonInput.deviceUID,
            name: "Orbisonic Roon Input",
            manufacturer: "Orbisonic"
        )
        let spotify = inputRoute(
            uid: OrbisonicLoopbackDevice.spotifyInput.deviceUID,
            name: "Orbisonic Spotify Input",
            manufacturer: "Orbisonic"
        )
        let aux = inputRoute(
            uid: OrbisonicLoopbackDevice.auxCable.deviceUID,
            name: "Orbisonic Aux Cable",
            manufacturer: "Orbisonic"
        )

        XCTAssertTrue(SourceMode.spotify.acceptsInputRoute(spotify))
        XCTAssertFalse(SourceMode.spotify.acceptsInputRoute(aux))
        XCTAssertFalse(SourceMode.spotify.acceptsInputRoute(roon))
        XCTAssertTrue(SourceMode.aux.acceptsInputRoute(aux))
        XCTAssertFalse(SourceMode.aux.acceptsInputRoute(spotify))
        XCTAssertTrue(SourceMode.roon.acceptsInputRoute(roon))
        XCTAssertFalse(SourceMode.roon.acceptsInputRoute(spotify))
    }

    func testMissingSpotifyLoopbackUsesSpotifySpecificSetupMessage() {
        let message = SourceMode.spotify.missingLoopbackMessage()

        XCTAssertTrue(message.contains("Orbisonic Spotify Input"))
        XCTAssertTrue(message.contains("Spotify support"))
    }

    func testSpotifyIsStereoOnlyAndDoesNotExposeRoonTransport() {
        XCTAssertEqual(SourceMode.spotify.fixedLiveChannelCount, 2)
        XCTAssertTrue(SourceMode.spotify.isLiveInput)
        XCTAssertFalse(SourceMode.spotify.exposesRoonMetadataAndTransport)
        XCTAssertTrue(SourceMode.roon.exposesRoonMetadataAndTransport)
    }

    func testRoonLiveChannelPolicyAllowsCommonLayoutsUpToEightChannels() {
        XCTAssertEqual(
            LiveChannelCountPolicy.availableCounts(sourceMode: .roon, availableInputChannels: 8),
            [2, 4, 6, 8]
        )
        XCTAssertEqual(
            LiveChannelCountPolicy.availableCounts(sourceMode: .roon, availableInputChannels: 64),
            [2, 4, 6, 8]
        )
        XCTAssertEqual(
            LiveChannelCountPolicy.preferredCount(sourceMode: .roon, availableInputChannels: 8, activeCount: 8),
            8
        )
        XCTAssertEqual(
            LiveChannelCountPolicy.preferredCount(sourceMode: .roon, availableInputChannels: 8, activeCount: 1),
            2
        )
        XCTAssertEqual(
            LiveChannelCountPolicy.preferredCount(sourceMode: .roon, availableInputChannels: 1, activeCount: 1),
            2
        )
    }

    func testSpotifyLiveChannelPolicyStaysStereoOnly() {
        XCTAssertEqual(
            LiveChannelCountPolicy.availableCounts(sourceMode: .spotify, availableInputChannels: 64),
            [2]
        )
        XCTAssertEqual(
            LiveChannelCountPolicy.preferredCount(sourceMode: .spotify, availableInputChannels: 64, activeCount: 8),
            2
        )
    }

    func testLiveSourcesStopCaptureWhenSwitchingSources() {
        XCTAssertTrue(SourceMode.spotify.stopsLiveCaptureWhenSwitching(to: .roon))
        XCTAssertTrue(SourceMode.spotify.stopsLiveCaptureWhenSwitching(to: .aux))
        XCTAssertTrue(SourceMode.spotify.stopsLiveCaptureWhenSwitching(to: .filePlayback))
        XCTAssertTrue(SourceMode.roon.stopsLiveCaptureWhenSwitching(to: .spotify))
        XCTAssertTrue(SourceMode.aux.stopsLiveCaptureWhenSwitching(to: .filePlayback))
        XCTAssertFalse(SourceMode.spotify.stopsLiveCaptureWhenSwitching(to: .spotify))
        XCTAssertFalse(SourceMode.filePlayback.stopsLiveCaptureWhenSwitching(to: .spotify))
    }

    func testSourceSwitchRequestStateSerializesAndKeepsLatestPendingSource() {
        var state = SourceSwitchRequestState()

        XCTAssertTrue(state.request(.spotify))
        XCTAssertFalse(state.request(.roon))
        XCTAssertFalse(state.request(.aux))
        XCTAssertEqual(state.takeNext(), .aux)

        XCTAssertFalse(state.request(.off))
        XCTAssertFalse(state.request(.filePlayback))
        XCTAssertEqual(state.coalescePending(over: .aux), .filePlayback)
        XCTAssertNil(state.takeNext())
        XCTAssertFalse(state.isProcessing)
    }

    func testInputRouteClassifiesLegacyBlackHoleSeparately() {
        let route = inputRoute(
            uid: "blackhole-64ch",
            name: "BlackHole 64ch",
            manufacturer: "Existential Audio"
        )

        XCTAssertEqual(route.role, .legacyBlackHole)
        XCTAssertTrue(route.isBlackHole)
        XCTAssertFalse(route.isOrbisonicLoopback)
    }

    func testOutputRouteBlocksOrbisonicLoopbackFeedback() {
        let route = OutputRouteInfo(
            deviceID: 42,
            uid: OrbisonicLoopbackDevice.spotifyInput.deviceUID,
            deviceName: "Orbisonic Spotify Input",
            manufacturer: "Orbisonic",
            transportName: "Virtual",
            outputChannelCount: 64,
            nominalSampleRate: 48_000
        )

        XCTAssertTrue(route.routeRisk.blocksLiveMonitoring)
        XCTAssertFalse(route.isSelectableOutputTarget)
    }

    func testOutputSelectionModePersistsNoneAndDeviceSelections() {
        XCTAssertEqual(OutputSelectionMode(storedValue: "none", defaultMode: .systemDefault), .none)
        XCTAssertEqual(OutputSelectionMode(storedValue: "system", defaultMode: .none), .systemDefault)
        XCTAssertEqual(OutputSelectionMode(storedValue: "automatic", defaultMode: .none), .none)
        XCTAssertEqual(OutputSelectionMode(storedValue: "device:abc", defaultMode: .none), .device("abc"))
        XCTAssertEqual(OutputSelectionMode(storedValue: nil, defaultMode: .none), .none)
        XCTAssertEqual(OutputSelectionMode.device("abc").storedValue, "device:abc")
    }

    func testMonitorOutputSelectionAllowsNoneAndSystemDefault() {
        let system = outputRoute(uid: "built-in", name: "MacBook Speakers", transport: "Built-In", channels: 2)
        let routes = [system]

        XCTAssertEqual(
            OutputRouteSelectionPolicy.monitorRoute(from: routes, selection: .none, systemOutput: system),
            .unavailable
        )
        XCTAssertEqual(
            OutputRouteSelectionPolicy.monitorRoute(from: routes, selection: .systemDefault, systemOutput: system).uid,
            system.uid
        )
    }

    func testStartupMonitorSelectionFallsBackFromNoneAndStaleDevicesToSystemDefault() {
        let system = outputRoute(uid: "built-in", name: "MacBook Speakers", transport: "Built-In", channels: 2)
        let selected = outputRoute(uid: "usb", name: "USB Headphones", transport: "USB", channels: 2)
        let routes = [system, selected]

        XCTAssertEqual(
            OutputRouteSelectionPolicy.startupMonitorSelection(
                from: routes,
                storedSelection: .none,
                systemOutput: system
            ),
            .systemDefault
        )
        XCTAssertEqual(
            OutputRouteSelectionPolicy.startupMonitorSelection(
                from: routes,
                storedSelection: .device("missing"),
                systemOutput: system
            ),
            .systemDefault
        )
    }

    func testStartupMonitorSelectionKeepsAvailableSelectableSavedDevice() {
        let system = outputRoute(uid: "built-in", name: "MacBook Speakers", transport: "Built-In", channels: 2)
        let selected = outputRoute(uid: "usb", name: "USB Headphones", transport: "USB", channels: 2)

        XCTAssertEqual(
            OutputRouteSelectionPolicy.startupMonitorSelection(
                from: [system, selected],
                storedSelection: .device(selected.uid),
                systemOutput: system
            ),
            .device(selected.uid)
        )
    }

    func testRendererOutputSelectionAllowsNone() {
        let system = outputRoute(uid: "built-in", name: "MacBook Speakers", transport: "Built-In", channels: 2)
        let selected = OutputRouteSelectionPolicy.rendererRoute(
            from: [system],
            selection: .none,
            systemOutput: system
        )

        XCTAssertEqual(selected, .unavailable)
    }

    func testRendererOutputSelectionDoesNotAutomaticallyPickDante() {
        let system = outputRoute(uid: "built-in", name: "MacBook Speakers", transport: "Built-In", channels: 2)
        let dante = outputRoute(uid: "dante-vsc", name: "Dante Virtual Soundcard", manufacturer: "Audinate", transport: "Virtual", channels: 32)
        let usb = outputRoute(uid: "usb-16", name: "USB 16ch Interface", transport: "USB", channels: 16)

        let selected = OutputRouteSelectionPolicy.rendererRoute(
            from: [system, usb, dante],
            selection: .none,
            systemOutput: system
        )

        XCTAssertTrue(dante.isPreferredRendererOutput)
        XCTAssertEqual(selected, .unavailable)
    }

    func testRendererOutputSelectionRequiresExplicitMultichannelOutput() {
        let system = outputRoute(uid: "built-in", name: "MacBook Speakers", transport: "Built-In", channels: 2)
        let usb = outputRoute(uid: "usb-16", name: "USB 16ch Interface", transport: "USB", channels: 16)

        let selected = OutputRouteSelectionPolicy.rendererRoute(
            from: [system, usb],
            selection: .none,
            systemOutput: system
        )

        XCTAssertTrue(usb.isRendererCapableOutput)
        XCTAssertEqual(selected, .unavailable)
    }

    func testRendererOutputSelectionAcceptsExplicitSafeMultichannelOutput() {
        let system = outputRoute(uid: "built-in", name: "MacBook Speakers", transport: "Built-In", channels: 2)
        let madi = outputRoute(uid: "madi-64", name: "MADIface USB", transport: "USB", channels: 64)

        let selected = OutputRouteSelectionPolicy.rendererRoute(
            from: [system, madi],
            selection: .device(madi.uid),
            systemOutput: system
        )

        XCTAssertEqual(selected.uid, madi.uid)
    }

    func testRendererOutputSelectionIgnoresBlockedLoopbackOutput() {
        let system = outputRoute(uid: "built-in", name: "MacBook Speakers", transport: "Built-In", channels: 2)
        let loopback = outputRoute(
            uid: OrbisonicLoopbackDevice.auxCable.deviceUID,
            name: "Orbisonic Aux Cable",
            manufacturer: "Orbisonic",
            transport: "Virtual",
            channels: 64
        )
        let usb = outputRoute(uid: "usb-16", name: "USB 16ch Interface", transport: "USB", channels: 16)

        let selected = OutputRouteSelectionPolicy.rendererRoute(
            from: [loopback, system, usb],
            selection: .device(loopback.uid),
            systemOutput: system
        )

        XCTAssertEqual(selected, .unavailable)
    }

    func testFeyRendererDoesNotUseDirectRendererAudioOnMonitorRoute() {
        let monitor = outputRoute(uid: "built-in", name: "MacBook Speakers", transport: "Built-In", channels: 2)
        let renderer = outputRoute(uid: "dante-vsc", name: "Dante Virtual Soundcard", manufacturer: "Audinate", transport: "Virtual", channels: 64)

        XCTAssertFalse(RendererAudioRoutingPolicy.usesDirectRendererAudio(
            renderMode: .quad,
            activeOutputRoute: monitor,
            rendererOutputRoute: renderer,
            requiredOutputChannelCount: 31
        ))
    }

    func testFeyRendererNeverUsesDirectRendererAudioOnExplicitRendererRoute() {
        let renderer = outputRoute(uid: "dante-vsc", name: "Dante Virtual Soundcard", manufacturer: "Audinate", transport: "Virtual", channels: 64)

        XCTAssertFalse(RendererAudioRoutingPolicy.usesDirectRendererAudio(
            renderMode: .quad,
            activeOutputRoute: renderer,
            rendererOutputRoute: renderer,
            requiredOutputChannelCount: 31
        ))
    }

    func testAutomaticModeNeverUsesDirectRendererAudioBeforeResolution() {
        let renderer = outputRoute(uid: "dante-vsc", name: "Dante Virtual Soundcard", manufacturer: "Audinate", transport: "Virtual", channels: 64)

        XCTAssertFalse(RendererAudioRoutingPolicy.usesDirectRendererAudio(
            renderMode: .automatic,
            activeOutputRoute: renderer,
            rendererOutputRoute: renderer,
            requiredOutputChannelCount: 31
        ))
    }

    func testDirectRendererAudioRequiresEnoughOutputChannels() {
        let renderer = outputRoute(uid: "usb-16", name: "USB 16ch Interface", transport: "USB", channels: 16)

        XCTAssertFalse(RendererAudioRoutingPolicy.usesDirectRendererAudio(
            renderMode: .quad,
            activeOutputRoute: renderer,
            rendererOutputRoute: renderer,
            requiredOutputChannelCount: 31
        ))
    }

    func testDanteHighRatePolicyOnlyWarnsAboveSixteenChannels() {
        XCTAssertFalse(DanteSafetyPolicy.requiresHighRateChannelWarning(outputChannelCount: 16, sampleRate: 192_000))
        XCTAssertTrue(DanteSafetyPolicy.requiresHighRateChannelWarning(outputChannelCount: 30, sampleRate: 192_000))
        XCTAssertFalse(DanteSafetyPolicy.requiresHighRateChannelWarning(outputChannelCount: 30, sampleRate: 96_000))
    }

    func testOutputRoutesMatchSameUidOrSameDeviceForNoOpSelection() {
        let current = OutputRouteInfo(
            deviceID: AudioDeviceID(42),
            uid: "built-in-speakers",
            deviceName: "MacBook Pro Speakers",
            manufacturer: "Apple",
            transportName: "Built-In",
            outputChannelCount: 2,
            nominalSampleRate: 44_100
        )
        let sameUID = OutputRouteInfo(
            deviceID: AudioDeviceID(84),
            uid: "built-in-speakers",
            deviceName: "MacBook Pro Speakers",
            manufacturer: "Apple",
            transportName: "Built-In",
            outputChannelCount: 2,
            nominalSampleRate: 44_100
        )
        let sameDevice = OutputRouteInfo(
            deviceID: AudioDeviceID(42),
            uid: "system-default",
            deviceName: "System Default",
            manufacturer: "Apple",
            transportName: "Built-In",
            outputChannelCount: 2,
            nominalSampleRate: 44_100
        )
        let other = outputRoute(uid: "usb-speakers", name: "USB Speakers", transport: "USB", channels: 2)

        XCTAssertTrue(current.matchesAudioDevice(sameUID))
        XCTAssertTrue(current.matchesAudioDevice(sameDevice))
        XCTAssertFalse(current.matchesAudioDevice(other))
        XCTAssertFalse(current.matchesAudioDevice(.unavailable))
    }

    private func inputRoute(uid: String, name: String, manufacturer: String) -> InputRouteInfo {
        InputRouteInfo(
            deviceID: AudioDeviceID(1),
            uid: uid,
            deviceName: name,
            manufacturer: manufacturer,
            transportName: "Virtual",
            inputChannelCount: 64,
            nominalSampleRate: 48_000
        )
    }

    private func outputRoute(
        uid: String,
        name: String,
        manufacturer: String = "",
        transport: String,
        channels: Int,
        sampleRate: Double = 48_000
    ) -> OutputRouteInfo {
        OutputRouteInfo(
            deviceID: AudioDeviceID(abs(uid.hashValue % 10_000) + 1),
            uid: uid,
            deviceName: name,
            manufacturer: manufacturer,
            transportName: transport,
            outputChannelCount: channels,
            nominalSampleRate: sampleRate
        )
    }

}
