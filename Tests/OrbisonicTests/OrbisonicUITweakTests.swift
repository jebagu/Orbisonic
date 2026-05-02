import XCTest

final class OrbisonicUITweakTests: XCTestCase {
    func testRendererPanelOwnsAtmosNoteAndTuningIsCollapsible() throws {
        let source = try source("Sources/Orbisonic/ContentView.swift")

        XCTAssertFalse(source.contains("Safe Tuning"))
        XCTAssertTrue(source.contains("title: \"Tuning\""))
        XCTAssertTrue(source.contains("isExpanded: $rendererTuningExpanded"))
        XCTAssertTrue(source.contains("infoRow(title: \"Atmos\", value: note)"))
        XCTAssertTrue(source.contains("rendererAtmosNoteText"))
    }

    func testSettingsCleanupAndOutputWebpagePanel() throws {
        let source = try source("Sources/Orbisonic/ContentView.swift")

        XCTAssertFalse(source.contains("settingsPanel(title: \"Web Pages\")"))
        XCTAssertFalse(source.contains("Album Art And Local Database"))
        XCTAssertFalse(source.contains("Logs And Diagnostics"))
        XCTAssertFalse(source.contains("infoRow(title: \"Status\", value: model.webServerStatus)"))
        XCTAssertTrue(source.contains("settingsPanel(title: \"Now playing on Sonic Sphere webpage (local network only)\""))
        XCTAssertTrue(source.contains("webURLRow(title: \"Link\", url: model.webPublicPageURL)"))
        XCTAssertFalse(source.contains("outputLanePanelHeight"))
        XCTAssertTrue(source.contains("OutputLaneNaturalHeightPreferenceKey"))
        XCTAssertTrue(source.contains("outputLaneEqualHeight"))
        XCTAssertTrue(source.contains("settingsPanel(title: \"Watch Folders\""))
        XCTAssertFalse(source.contains("settingsPanel(title: \"M3U Playlists\""))
        XCTAssertFalse(source.contains("Label(\"Add Music Folder\""))
        XCTAssertFalse(source.contains("Label(\"Add M3U\""))
        XCTAssertFalse(source.contains("Import M3U files"))
        XCTAssertFalse(source.contains("infoRow(title: \"Music\""))
        XCTAssertFalse(source.contains("infoRow(title: \"M3U\""))
        XCTAssertTrue(source.contains("Label(\"Add Folder\""))
        XCTAssertTrue(source.contains("Search subfolders"))
        XCTAssertTrue(source.contains("infoRow(title: \"Folders\""))
        XCTAssertTrue(source.contains("settingsPanel(title: \"Max Volume Limiter\""))
    }

    func testPlaylistContextMenusCanAddCurrentAndQueuedTracksToPlaylist() throws {
        let source = try source("Sources/Orbisonic/ContentView.swift")

        XCTAssertTrue(source.contains("private func addToPlaylistMenu(for track: LocalMusicTrack) -> some View"))
        XCTAssertGreaterThanOrEqual(source.components(separatedBy: "addToPlaylistMenu(for: track)").count - 1, 3)
        XCTAssertTrue(source.contains("model.addLocalMusicTrackToPlaylist(track, playlist)"))
        XCTAssertTrue(source.contains("beginCreatePlaylist(for: track)"))
    }

    func testPlaylistRowsExposeReorderAndDeleteActions() throws {
        let source = try source("Sources/Orbisonic/ContentView.swift")

        XCTAssertTrue(source.contains("model.moveLocalMusicPlaylistUp(playlist)"))
        XCTAssertTrue(source.contains("model.moveLocalMusicPlaylistDown(playlist)"))
        XCTAssertTrue(source.contains("beginDeletePlaylist(playlist)"))
        XCTAssertTrue(source.contains("Delete Playlist"))
        XCTAssertTrue(source.contains("Remove Playlist"))
    }

    func testSelectedPlaylistPanelDoesNotShowVisibleReorderButtons() throws {
        let source = try source("Sources/Orbisonic/ContentView.swift")
        let start = try XCTUnwrap(source.range(of: "private var localMusicSelectedPlaylistPanel"))
        let end = try XCTUnwrap(source.range(of: "private var localMusicQueuePanel", range: start.upperBound..<source.endIndex))
        let selectedPlaylistPanel = String(source[start.lowerBound..<end.lowerBound])

        XCTAssertFalse(selectedPlaylistPanel.contains("model.moveLocalMusicPlaylistUp(playlist)"))
        XCTAssertFalse(selectedPlaylistPanel.contains("model.moveLocalMusicPlaylistDown(playlist)"))
        XCTAssertFalse(selectedPlaylistPanel.contains("Label(\"Move Up\""))
        XCTAssertFalse(selectedPlaylistPanel.contains("Label(\"Move Down\""))
    }

    func testDiagnosticsClosablePanelsDefaultCollapsed() throws {
        let source = try source("Sources/Orbisonic/DiagnosticsView.swift")

        XCTAssertFalse(source.contains("defaultExpanded: true"))
        XCTAssertFalse(source.contains("defaultExpanded: model.sourceMode"))
        XCTAssertFalse(source.contains("defaultExpanded || !warnings.isEmpty"))
        XCTAssertTrue(source.contains("expansionBinding(for: id, defaultExpanded: defaultExpanded)"))
    }

    func testLoadingStatusChipUsesAnimatedCrosshatch() throws {
        let source = try source("Sources/Orbisonic/ContentView.swift")

        XCTAssertTrue(source.contains("StatusChipBackground"))
        XCTAssertTrue(source.contains("LoadingCrosshatchStripePattern"))
        XCTAssertTrue(source.contains("TimelineView(.animation)"))
        XCTAssertTrue(source.contains("statusChipIsLoading"))
    }

    func testPlayerArtworkUsesLargeVerticalMediaLayout() throws {
        let source = try source("Sources/Orbisonic/ContentView.swift")
        let artworkStart = try XCTUnwrap(source.range(of: "private struct PlayerArtworkView"))
        let artworkEnd = try XCTUnwrap(source.range(of: "struct ContentView", range: artworkStart.upperBound..<source.endIndex))
        let artworkView = String(source[artworkStart.lowerBound..<artworkEnd.lowerBound])
        let mediaStart = try XCTUnwrap(source.range(of: "private var nowPlayingMediaBlock"))
        let mediaEnd = try XCTUnwrap(source.range(of: "private var playerTransportControls", range: mediaStart.upperBound..<source.endIndex))
        let mediaBlock = String(source[mediaStart.lowerBound..<mediaEnd.lowerBound])

        XCTAssertFalse(artworkView.contains("private let size: CGFloat = 58"))
        XCTAssertFalse(artworkView.contains(".frame(width: size, height: size)"))
        XCTAssertTrue(artworkView.contains(".aspectRatio(1, contentMode: .fit)"))
        XCTAssertTrue(artworkView.contains(".frame(maxWidth: .infinity)"))
        XCTAssertTrue(mediaBlock.contains("VStack(alignment: .leading, spacing: 10)"))
        XCTAssertFalse(mediaBlock.contains("HStack(alignment: .center, spacing: 12)"))
        XCTAssertTrue(mediaBlock.contains("PlayerArtworkView(url: nowPlayingArtworkURL)"))
        XCTAssertTrue(mediaBlock.contains("Text(nowPlayingTitle)"))
        XCTAssertTrue(mediaBlock.contains("Text(nowPlayingSubtitle)"))
        XCTAssertTrue(mediaBlock.contains("addToPlaylistMenu(for: track)"))
    }

    private func source(_ relativePath: String) throws -> String {
        try String(contentsOf: packageRoot().appendingPathComponent(relativePath), encoding: .utf8)
    }

    private func packageRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
