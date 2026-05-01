import AVFoundation
import Foundation

struct LocalMusicSettings: Codable, Equatable, Sendable {
    var watchFolderPaths: [String] = []
    var m3uPlaylistPaths: [String] = []
    var scansSubfolders = true
    var importsM3UPlaylists = true
    var extractsAlbumArt = true
}

struct LocalMusicDatabase: Codable, Equatable, Sendable {
    var settings = LocalMusicSettings()
    var tracks: [LocalMusicTrack] = []
    var playlists: [LocalMusicPlaylist] = []
}

struct LocalMusicTrack: Identifiable, Codable, Equatable, Sendable {
    let path: String
    let rootPath: String?
    let fileName: String
    let title: String?
    let artist: String?
    let album: String?
    let channelCount: Int
    let channelSummary: String
    let layoutName: String
    let sampleRate: Double
    let duration: TimeInterval
    let artworkPath: String?

    var id: String { path }
    var url: URL { URL(fileURLWithPath: path) }
    var fallbackTitle: String { URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent }

    var displayTitle: String {
        title?.trimmedNilIfBlank ?? fallbackTitle
    }

    var displayArtist: String {
        artist?.trimmedNilIfBlank ?? "-"
    }

    var displayAlbum: String {
        album?.trimmedNilIfBlank ?? "-"
    }

    var displaySubtitle: String {
        let metadata = [artist?.trimmedNilIfBlank, album?.trimmedNilIfBlank].compactMap { $0 }
        return metadata.isEmpty ? displayPath : metadata.joined(separator: " • ")
    }

    var channelText: String {
        guard channelCount > 0 else { return "-" }
        return "\(channelCount) ch"
    }

    var channelDetailText: String {
        guard channelCount > 0 else { return "-" }
        return channelSummary.isEmpty ? "\(channelCount) ch" : "\(channelCount) (\(channelSummary))"
    }

    var sampleRateText: String {
        guard sampleRate > 0 else { return "-" }
        if sampleRate >= 1_000 {
            return String(format: "%.1f kHz", sampleRate / 1_000)
        }
        return String(format: "%.0f Hz", sampleRate)
    }

    var durationText: String {
        Self.formatDuration(duration)
    }

    var sortName: String { displayTitle }
    var sortArtist: String { artist?.trimmedNilIfBlank ?? "" }
    var sortAlbum: String { album?.trimmedNilIfBlank ?? "" }

    var displayPath: String {
        let folderPath = URL(fileURLWithPath: path).deletingLastPathComponent().path
        guard let rootPath else { return folderPath }

        if folderPath == rootPath {
            return URL(fileURLWithPath: rootPath).lastPathComponent
        }

        let prefix = rootPath.hasSuffix("/") ? rootPath : "\(rootPath)/"
        if folderPath.hasPrefix(prefix) {
            return String(folderPath.dropFirst(prefix.count))
        }

        return folderPath
    }

    func matches(_ query: String) -> Bool {
        let fields = [
            fileName,
            displayTitle,
            artist ?? "",
            album ?? "",
            channelText,
            layoutName,
            displayPath
        ]

        return fields.contains { $0.localizedCaseInsensitiveContains(query) }
    }

    private static func formatDuration(_ value: TimeInterval) -> String {
        let totalSeconds = max(Int(value.rounded(.down)), 0)
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct LocalMusicPlaylist: Identifiable, Codable, Equatable, Sendable {
    let name: String
    let path: String
    let trackPaths: [String]

    var id: String { path }
    var fileName: String { URL(fileURLWithPath: path).lastPathComponent }
}

enum LocalMusicPlaylistMutationError: LocalizedError, Equatable {
    case duplicateTrack
    case invalidName
    case readOnly
    case playlistMissing
    case nameConflict(String)

    var errorDescription: String? {
        switch self {
        case .duplicateTrack:
            return "That song is already in this playlist."
        case .invalidName:
            return "Playlist name is required."
        case .readOnly:
            return "Imported playlists are read-only. Save or create an Orbisonic playlist to edit it."
        case .playlistMissing:
            return "The playlist file could not be found."
        case .nameConflict(let name):
            return "A playlist named \(name) already exists."
        }
    }
}

struct LocalMusicScanResult: Sendable {
    let tracks: [LocalMusicTrack]
    let playlists: [LocalMusicPlaylist]
    let skippedMissingFiles: Int
}

private struct LocalMusicURLCollection {
    let urls: [URL]
    let skippedMissingFiles: Int
}

private struct M3UParseResult {
    let urls: [URL]
    let skippedMissingFiles: Int
}

final class LocalMusicLibrary {
    private let fileManager: FileManager
    private let databaseURL: URL
    private let artworkDirectoryURL: URL
    private let playlistDirectoryURL: URL

    init(fileManager: FileManager = .default, supportURL: URL? = nil) {
        self.fileManager = fileManager
        let supportURL = supportURL ?? Self.applicationSupportURL(fileManager: fileManager)
        try? fileManager.createDirectory(at: supportURL, withIntermediateDirectories: true)
        databaseURL = supportURL.appendingPathComponent("local-music-library.json", isDirectory: false)
        artworkDirectoryURL = supportURL.appendingPathComponent("Album Artwork", isDirectory: true)
        playlistDirectoryURL = supportURL.appendingPathComponent("Playlists", isDirectory: true)
        try? fileManager.createDirectory(at: artworkDirectoryURL, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: playlistDirectoryURL, withIntermediateDirectories: true)
    }

    var databasePath: String {
        databaseURL.path
    }

    var artworkDirectoryPath: String {
        artworkDirectoryURL.path
    }

    var playlistDirectoryPath: String {
        playlistDirectoryURL.path
    }

    func isEditablePlaylist(_ playlist: LocalMusicPlaylist) -> Bool {
        isManagedPlaylistURL(URL(fileURLWithPath: playlist.path))
    }

    func load() -> LocalMusicDatabase {
        guard let data = try? Data(contentsOf: databaseURL) else {
            return LocalMusicDatabase()
        }

        do {
            let database = try JSONDecoder().decode(LocalMusicDatabase.self, from: data)
            let pruned = pruneMissingFiles(in: database)
            let repaired = repairStaleMatroskaMetadata(in: pruned)
            if repaired != database {
                save(repaired)
            }
            return repaired
        } catch {
            AppLogger.shared.error(category: "local-music", "Failed to decode local music database: \(error.localizedDescription)")
            return LocalMusicDatabase()
        }
    }

    func save(_ database: LocalMusicDatabase) {
        do {
            try fileManager.createDirectory(at: databaseURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(database)
            try data.write(to: databaseURL, options: .atomic)
        } catch {
            AppLogger.shared.error(category: "local-music", "Failed to save local music database: \(error.localizedDescription)")
        }
    }

    func scan(settings: LocalMusicSettings) -> LocalMusicScanResult {
        let collected = collectAudioURLs(settings: settings)
        let tracks = collected.urls.map { url in
            metadata(for: url, rootPath: rootPath(for: url, settings: settings), extractsAlbumArt: settings.extractsAlbumArt)
        }
        let tracksByPath = Dictionary(uniqueKeysWithValues: tracks.map { ($0.path, $0) })
        let playlists = settings.importsM3UPlaylists
            ? collectPlaylists(settings: settings, tracksByPath: tracksByPath)
            : []

        return LocalMusicScanResult(
            tracks: tracks.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending },
            playlists: playlists.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending },
            skippedMissingFiles: collected.skippedMissingFiles
        )
    }

    func saveSessionPlaylist(name: String, tracks: [LocalMusicTrack]) throws -> LocalMusicPlaylist {
        try fileManager.createDirectory(at: playlistDirectoryURL, withIntermediateDirectories: true)

        let fileStem = Self.sanitizedFileStem(name)
        let playlistURL = uniquePlaylistURL(fileStem: fileStem)
        try writePlaylist(
            to: playlistURL,
            trackPaths: tracks.map(\.path),
            tracksByPath: tracksByPath(for: tracks)
        )

        return LocalMusicPlaylist(
            name: playlistURL.deletingPathExtension().lastPathComponent,
            path: playlistURL.path,
            trackPaths: tracks.map(\.path)
        )
    }

    func createPlaylist(name: String, tracks: [LocalMusicTrack]) throws -> LocalMusicPlaylist {
        try saveSessionPlaylist(name: name, tracks: tracks)
    }

    func appendTrack(
        _ track: LocalMusicTrack,
        to playlist: LocalMusicPlaylist,
        knownTracks: [LocalMusicTrack]
    ) throws -> LocalMusicPlaylist {
        guard isEditablePlaylist(playlist) else {
            throw LocalMusicPlaylistMutationError.readOnly
        }
        guard !playlist.trackPaths.contains(track.path) else {
            throw LocalMusicPlaylistMutationError.duplicateTrack
        }

        return try updateEditablePlaylist(
            playlist,
            trackPaths: playlist.trackPaths + [track.path],
            knownTracks: knownTracks + [track]
        )
    }

    func updateEditablePlaylist(
        _ playlist: LocalMusicPlaylist,
        trackPaths: [String],
        knownTracks: [LocalMusicTrack]
    ) throws -> LocalMusicPlaylist {
        guard isEditablePlaylist(playlist) else {
            throw LocalMusicPlaylistMutationError.readOnly
        }

        let playlistURL = URL(fileURLWithPath: playlist.path)
        try fileManager.createDirectory(at: playlistDirectoryURL, withIntermediateDirectories: true)
        try writePlaylist(
            to: playlistURL,
            trackPaths: trackPaths,
            tracksByPath: tracksByPath(for: knownTracks)
        )

        return LocalMusicPlaylist(
            name: playlistURL.deletingPathExtension().lastPathComponent,
            path: playlistURL.path,
            trackPaths: trackPaths
        )
    }

    func renameEditablePlaylist(_ playlist: LocalMusicPlaylist, to rawName: String) throws -> LocalMusicPlaylist {
        guard isEditablePlaylist(playlist) else {
            throw LocalMusicPlaylistMutationError.readOnly
        }

        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            throw LocalMusicPlaylistMutationError.invalidName
        }

        let currentURL = URL(fileURLWithPath: playlist.path)
        let fileStem = Self.sanitizedFileStem(name)
        let targetURL = playlistDirectoryURL
            .appendingPathComponent(fileStem, isDirectory: false)
            .appendingPathExtension("m3u")

        if currentURL.standardizedFileURL.path == targetURL.standardizedFileURL.path {
            return LocalMusicPlaylist(
                name: targetURL.deletingPathExtension().lastPathComponent,
                path: currentURL.path,
                trackPaths: playlist.trackPaths
            )
        }

        guard !fileManager.fileExists(atPath: targetURL.path) else {
            throw LocalMusicPlaylistMutationError.nameConflict(targetURL.deletingPathExtension().lastPathComponent)
        }
        guard fileManager.fileExists(atPath: currentURL.path) else {
            throw LocalMusicPlaylistMutationError.playlistMissing
        }

        try fileManager.moveItem(at: currentURL, to: targetURL)
        return LocalMusicPlaylist(
            name: targetURL.deletingPathExtension().lastPathComponent,
            path: targetURL.path,
            trackPaths: playlist.trackPaths
        )
    }

    private func collectAudioURLs(settings: LocalMusicSettings) -> LocalMusicURLCollection {
        var seenPaths = Set<String>()
        var urls: [URL] = []
        var skippedMissingFiles = 0

        for folderPath in settings.watchFolderPaths {
            let folderURL = URL(fileURLWithPath: folderPath)
            let candidates = audioURLs(in: folderURL, recursive: settings.scansSubfolders)
            for url in candidates where seenPaths.insert(url.path).inserted {
                urls.append(url)
            }
        }

        if settings.importsM3UPlaylists {
            for playlistPath in settings.m3uPlaylistPaths {
                let playlistURL = URL(fileURLWithPath: playlistPath)
                let parsed = parseM3U(at: playlistURL)
                skippedMissingFiles += parsed.skippedMissingFiles
                for url in parsed.urls where seenPaths.insert(url.path).inserted {
                    urls.append(url)
                }
            }
        }

        return LocalMusicURLCollection(urls: urls, skippedMissingFiles: skippedMissingFiles)
    }

    private func audioURLs(in folderURL: URL, recursive: Bool) -> [URL] {
        let keys: [URLResourceKey] = [.isRegularFileKey, .isDirectoryKey, .isPackageKey]

        if recursive,
           let enumerator = fileManager.enumerator(
               at: folderURL,
               includingPropertiesForKeys: keys,
               options: [.skipsHiddenFiles, .skipsPackageDescendants]
           ) {
            return enumerator.compactMap { item in
                guard let url = item as? URL else { return nil }
                return Self.isSupportedAudioFile(url) ? url : nil
            }
        }

        return (try? fileManager.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        ).filter(Self.isSupportedAudioFile)) ?? []
    }

    private func collectPlaylists(settings: LocalMusicSettings, tracksByPath: [String: LocalMusicTrack]) -> [LocalMusicPlaylist] {
        var playlistURLs: [URL] = settings.m3uPlaylistPaths.map { URL(fileURLWithPath: $0) }
        var seenPlaylistPaths = Set(playlistURLs.map(\.path))

        for folderPath in settings.watchFolderPaths {
            let folderURL = URL(fileURLWithPath: folderPath)
            let candidates = m3uURLs(in: folderURL, recursive: settings.scansSubfolders)
            for url in candidates where seenPlaylistPaths.insert(url.path).inserted {
                playlistURLs.append(url)
            }
        }

        return playlistURLs.compactMap { playlistURL in
            let trackPaths = parseM3U(at: playlistURL).urls
                .map(\.path)
                .filter { tracksByPath[$0] != nil || fileManager.fileExists(atPath: $0) }
            guard !trackPaths.isEmpty || isManagedPlaylistURL(playlistURL) else { return nil }
            return LocalMusicPlaylist(
                name: playlistURL.deletingPathExtension().lastPathComponent,
                path: playlistURL.path,
                trackPaths: trackPaths
            )
        }
    }

    private func m3uURLs(in folderURL: URL, recursive: Bool) -> [URL] {
        let keys: [URLResourceKey] = [.isRegularFileKey]

        if recursive,
           let enumerator = fileManager.enumerator(
               at: folderURL,
               includingPropertiesForKeys: keys,
               options: [.skipsHiddenFiles, .skipsPackageDescendants]
           ) {
            return enumerator.compactMap { item in
                guard let url = item as? URL else { return nil }
                return Self.isM3UPlaylist(url) ? url : nil
            }
        }

        return (try? fileManager.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        ).filter(Self.isM3UPlaylist)) ?? []
    }

    private func parseM3U(at playlistURL: URL) -> M3UParseResult {
        guard let contents = try? String(contentsOf: playlistURL, encoding: .utf8) else {
            return M3UParseResult(urls: [], skippedMissingFiles: 0)
        }

        let baseURL = playlistURL.deletingLastPathComponent()
        var skippedMissingFiles = 0
        let urls = contents
            .components(separatedBy: .newlines)
            .compactMap { line -> URL? in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { return nil }

                let url: URL
                if trimmed.hasPrefix("/") {
                    url = URL(fileURLWithPath: trimmed)
                } else if let parsedURL = URL(string: trimmed), parsedURL.isFileURL {
                    url = parsedURL
                } else {
                    url = baseURL.appendingPathComponent(trimmed).standardizedFileURL
                }

                guard Self.isSupportedAudioFile(url) else { return nil }
                guard fileManager.fileExists(atPath: url.path) else {
                    skippedMissingFiles += 1
                    return nil
                }
                return url
            }
        return M3UParseResult(urls: urls, skippedMissingFiles: skippedMissingFiles)
    }

    private func metadata(for url: URL, rootPath: String?, extractsAlbumArt: Bool) -> LocalMusicTrack {
        if MatroskaFLACSupport.isMatroska(url) {
            return matroskaMetadata(for: url, rootPath: rootPath, extractsAlbumArt: extractsAlbumArt)
        }

        let asset = AVURLAsset(url: url)
        let commonMetadata = asset.commonMetadata
        let title = Self.metadataString(for: .commonKeyTitle, in: commonMetadata)
        let artist = Self.metadataString(for: .commonKeyArtist, in: commonMetadata)
        let album = Self.metadataString(for: .commonKeyAlbumName, in: commonMetadata)
        let artworkPath = extractsAlbumArt ? extractArtwork(for: url, metadata: commonMetadata) : nil

        do {
            let file = try AVAudioFile(forReading: url)
            let layout = SurroundLayoutDetector.detect(for: file.processingFormat)
            let duration = file.fileFormat.sampleRate > 0 ? Double(file.length) / file.fileFormat.sampleRate : 0

            return LocalMusicTrack(
                path: url.path,
                rootPath: rootPath,
                fileName: url.lastPathComponent,
                title: title,
                artist: artist,
                album: album,
                channelCount: Int(file.processingFormat.channelCount),
                channelSummary: layout.channelSummary,
                layoutName: layout.name,
                sampleRate: file.fileFormat.sampleRate,
                duration: duration,
                artworkPath: artworkPath
            )
        } catch {
            AppLogger.shared.error(category: "local-music", "Metadata scan failed file=\(url.path) error=\(error.localizedDescription)")
            return LocalMusicTrack(
                path: url.path,
                rootPath: rootPath,
                fileName: url.lastPathComponent,
                title: title,
                artist: artist,
                album: album,
                channelCount: 0,
                channelSummary: "",
                layoutName: "-",
                sampleRate: 0,
                duration: 0,
                artworkPath: artworkPath
            )
        }
    }

    private func repairStaleMatroskaMetadata(in database: LocalMusicDatabase) -> LocalMusicDatabase {
        var repaired = database
        var changed = false
        repaired.tracks = database.tracks.map { track in
            guard track.channelCount <= 0,
                  MatroskaFLACSupport.isMatroska(track.url),
                  fileManager.fileExists(atPath: track.path)
            else {
                return track
            }

            changed = true
            return matroskaMetadata(
                for: track.url,
                rootPath: track.rootPath,
                extractsAlbumArt: database.settings.extractsAlbumArt
            )
        }

        return changed ? repaired : database
    }

    private func pruneMissingFiles(in database: LocalMusicDatabase) -> LocalMusicDatabase {
        let existingTracks = database.tracks.filter { fileManager.fileExists(atPath: $0.path) }
        let existingTrackPaths = Set(existingTracks.map(\.path))

        let playlists = database.playlists.compactMap { playlist -> LocalMusicPlaylist? in
            let trackPaths = playlist.trackPaths.filter { path in
                existingTrackPaths.contains(path) || fileManager.fileExists(atPath: path)
            }
            guard !trackPaths.isEmpty || isEditablePlaylist(playlist) else { return nil }
            return LocalMusicPlaylist(name: playlist.name, path: playlist.path, trackPaths: trackPaths)
        }

        guard existingTracks.count != database.tracks.count || playlists != database.playlists else {
            return database
        }

        AppLogger.shared.notice(
            category: "local-music",
            "Pruned missing local music tracks removed=\(database.tracks.count - existingTracks.count)"
        )

        return LocalMusicDatabase(
            settings: database.settings,
            tracks: existingTracks,
            playlists: playlists
        )
    }

    private func matroskaMetadata(for url: URL, rootPath: String?, extractsAlbumArt: Bool) -> LocalMusicTrack {
        do {
            let streamInfo = try MatroskaAudioProbe().probe(url: url)
            let layout = SurroundLayoutDetector.fallbackLayout(for: streamInfo.channelCount)
            return LocalMusicTrack(
                path: url.path,
                rootPath: rootPath,
                fileName: url.lastPathComponent,
                title: streamInfo.tags.title,
                artist: streamInfo.tags.artist,
                album: streamInfo.tags.album,
                channelCount: streamInfo.channelCount,
                channelSummary: layout.channelSummary,
                layoutName: layout.name,
                sampleRate: streamInfo.sampleRate,
                duration: streamInfo.duration,
                artworkPath: extractsAlbumArt ? extractMatroskaArtwork(for: url) : nil
            )
        } catch {
            AppLogger.shared.error(category: "local-music", "Matroska metadata scan failed file=\(url.path) error=\(error.localizedDescription)")
            return LocalMusicTrack(
                path: url.path,
                rootPath: rootPath,
                fileName: url.lastPathComponent,
                title: nil,
                artist: nil,
                album: nil,
                channelCount: 0,
                channelSummary: "",
                layoutName: "-",
                sampleRate: 0,
                duration: 0,
                artworkPath: extractsAlbumArt ? extractMatroskaArtwork(for: url) : nil
            )
        }
    }

    private func extractMatroskaArtwork(for url: URL) -> String? {
        guard let ffmpegURL = FFmpegToolLocator.ffmpegURL() else { return nil }

        let filename = "\(Self.stableIdentifier(for: url.path)).jpg"
        let destinationURL = artworkDirectoryURL.appendingPathComponent(filename, isDirectory: false)
        if fileManager.fileExists(atPath: destinationURL.path) {
            return destinationURL.path
        }

        let process = Process()
        process.executableURL = ffmpegURL
        process.arguments = [
            "-y",
            "-v", "error",
            "-i", url.path,
            "-map", "0:v:0",
            "-frames:v", "1",
            destinationURL.path
        ]

        let pipe = Pipe()
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            AppLogger.shared.debug(category: "local-music", "Matroska artwork extraction could not start file=\(url.path) error=\(error.localizedDescription)")
            return nil
        }

        guard process.terminationStatus == 0,
              fileManager.fileExists(atPath: destinationURL.path)
        else {
            try? fileManager.removeItem(at: destinationURL)
            return nil
        }

        return destinationURL.path
    }

    private func extractArtwork(for url: URL, metadata: [AVMetadataItem]) -> String? {
        guard let artworkData = AVMetadataItem
            .metadataItems(from: metadata, withKey: AVMetadataKey.commonKeyArtwork, keySpace: .common)
            .first?
            .dataValue,
              !artworkData.isEmpty
        else {
            return nil
        }

        let ext = Self.artworkExtension(for: artworkData)
        let filename = "\(Self.stableIdentifier(for: url.path)).\(ext)"
        let destinationURL = artworkDirectoryURL.appendingPathComponent(filename, isDirectory: false)

        do {
            if !fileManager.fileExists(atPath: destinationURL.path) {
                try artworkData.write(to: destinationURL, options: .atomic)
            }
            return destinationURL.path
        } catch {
            AppLogger.shared.error(category: "local-music", "Artwork extraction failed file=\(url.path) error=\(error.localizedDescription)")
            return nil
        }
    }

    private func rootPath(for url: URL, settings: LocalMusicSettings) -> String? {
        settings.watchFolderPaths
            .sorted { $0.count > $1.count }
            .first { watchPath in
                let prefix = watchPath.hasSuffix("/") ? watchPath : "\(watchPath)/"
                return url.path == watchPath || url.path.hasPrefix(prefix)
            }
    }

    private static func metadataString(for key: AVMetadataKey, in metadata: [AVMetadataItem]) -> String? {
        AVMetadataItem.metadataItems(from: metadata, withKey: key, keySpace: .common)
            .first?
            .stringValue?
            .trimmedNilIfBlank
    }

    static func isSupportedAudioFile(_ url: URL) -> Bool {
        let supportedExtensions: Set<String> = [
            "wav", "wave", "flac", "aif", "aiff", "m4a", "caf", "mp3", "mkv", "mka"
        ]

        return supportedExtensions.contains(url.pathExtension.lowercased())
    }

    static func isM3UPlaylist(_ url: URL) -> Bool {
        let supportedExtensions: Set<String> = ["m3u", "m3u8"]
        return supportedExtensions.contains(url.pathExtension.lowercased())
    }

    private static func artworkExtension(for data: Data) -> String {
        if data.starts(with: [0x89, 0x50, 0x4E, 0x47]) {
            return "png"
        }
        return "jpg"
    }

    private static func stableIdentifier(for value: String) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return String(hash, radix: 16)
    }

    private static func sanitizedFileStem(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " -_"))
        let scalars = value.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : "-"
        }
        let stem = String(scalars)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "  ", with: " ")
        return stem.isEmpty ? "Session Queue" : stem
    }

    private func isManagedPlaylistURL(_ url: URL) -> Bool {
        Self.isM3UPlaylist(url) &&
            url.deletingLastPathComponent().standardizedFileURL.path == playlistDirectoryURL.standardizedFileURL.path
    }

    private func writePlaylist(
        to playlistURL: URL,
        trackPaths: [String],
        tracksByPath: [String: LocalMusicTrack]
    ) throws {
        let lines = ["#EXTM3U"] + trackPaths.flatMap { path in
            let track = tracksByPath[path]
            let duration = track.map { Int($0.duration.rounded(.down)) } ?? -1
            let title = track?.displayTitle ?? URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
            return [
                "#EXTINF:\(duration),\(title)",
                path
            ]
        }
        let contents = lines.joined(separator: "\n") + "\n"
        try contents.write(to: playlistURL, atomically: true, encoding: .utf8)
    }

    private func tracksByPath(for tracks: [LocalMusicTrack]) -> [String: LocalMusicTrack] {
        tracks.reduce(into: [:]) { result, track in
            result[track.path] = track
        }
    }

    private func uniquePlaylistURL(fileStem: String) -> URL {
        var candidate = playlistDirectoryURL.appendingPathComponent(fileStem, isDirectory: false).appendingPathExtension("m3u")
        var suffix = 2
        while fileManager.fileExists(atPath: candidate.path) {
            candidate = playlistDirectoryURL
                .appendingPathComponent("\(fileStem) \(suffix)", isDirectory: false)
                .appendingPathExtension("m3u")
            suffix += 1
        }
        return candidate
    }

    private static func applicationSupportURL(fileManager: FileManager) -> URL {
        if let url = try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("Orbisonic", isDirectory: true) {
            try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
            return url
        }

        let fallbackURL = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Application Support/Orbisonic", isDirectory: true)
        try? fileManager.createDirectory(at: fallbackURL, withIntermediateDirectories: true)
        return fallbackURL
    }
}

extension String {
    var trimmedNilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
