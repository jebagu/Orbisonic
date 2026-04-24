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

struct LocalMusicScanResult: Sendable {
    let tracks: [LocalMusicTrack]
    let playlists: [LocalMusicPlaylist]
}

final class LocalMusicLibrary {
    private let fileManager: FileManager
    private let databaseURL: URL
    private let artworkDirectoryURL: URL

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let supportURL = Self.applicationSupportURL(fileManager: fileManager)
        databaseURL = supportURL.appendingPathComponent("local-music-library.json", isDirectory: false)
        artworkDirectoryURL = supportURL.appendingPathComponent("Album Artwork", isDirectory: true)
        try? fileManager.createDirectory(at: artworkDirectoryURL, withIntermediateDirectories: true)
    }

    var databasePath: String {
        databaseURL.path
    }

    var artworkDirectoryPath: String {
        artworkDirectoryURL.path
    }

    func load() -> LocalMusicDatabase {
        guard let data = try? Data(contentsOf: databaseURL) else {
            return LocalMusicDatabase()
        }

        do {
            return try JSONDecoder().decode(LocalMusicDatabase.self, from: data)
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
        let audioURLs = collectAudioURLs(settings: settings)
        let tracks = audioURLs.map { url in
            metadata(for: url, rootPath: rootPath(for: url, settings: settings), extractsAlbumArt: settings.extractsAlbumArt)
        }
        let tracksByPath = Dictionary(uniqueKeysWithValues: tracks.map { ($0.path, $0) })
        let playlists = settings.importsM3UPlaylists
            ? collectPlaylists(settings: settings, tracksByPath: tracksByPath)
            : []

        return LocalMusicScanResult(
            tracks: tracks.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending },
            playlists: playlists.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        )
    }

    private func collectAudioURLs(settings: LocalMusicSettings) -> [URL] {
        var seenPaths = Set<String>()
        var urls: [URL] = []

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
                for url in parseM3U(at: playlistURL) where seenPaths.insert(url.path).inserted {
                    urls.append(url)
                }
            }
        }

        return urls
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
            let trackPaths = parseM3U(at: playlistURL)
                .map(\.path)
                .filter { tracksByPath[$0] != nil || fileManager.fileExists(atPath: $0) }
            guard !trackPaths.isEmpty else { return nil }
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

    private func parseM3U(at playlistURL: URL) -> [URL] {
        guard let contents = try? String(contentsOf: playlistURL, encoding: .utf8) else {
            return []
        }

        let baseURL = playlistURL.deletingLastPathComponent()
        return contents
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
                return url
            }
    }

    private func metadata(for url: URL, rootPath: String?, extractsAlbumArt: Bool) -> LocalMusicTrack {
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
            "wav", "wave", "flac", "aif", "aiff", "m4a", "caf", "mp3"
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

private extension String {
    var trimmedNilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
