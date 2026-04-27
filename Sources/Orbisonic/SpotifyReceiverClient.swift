import Foundation
import Darwin

#if ORBISONIC_ENABLE_EMBEDDED_LIBRESPOT
private struct OrbisonicLibrespotConfig {
    let receiverName: UnsafePointer<CChar>?
    let loopbackDeviceName: UnsafePointer<CChar>?
    let loopbackDeviceUID: UnsafePointer<CChar>?
    let supportDirectoryPath: UnsafePointer<CChar>?
    let cacheDirectoryPath: UnsafePointer<CChar>?
    let logDirectoryPath: UnsafePointer<CChar>?
}

@_silgen_name("orbisonic_librespot_start")
private func orbisonicLibrespotStart(_ config: UnsafePointer<OrbisonicLibrespotConfig>) -> Int32

@_silgen_name("orbisonic_librespot_stop")
private func orbisonicLibrespotStop() -> Int32

@_silgen_name("orbisonic_librespot_play_pause")
private func orbisonicLibrespotPlayPause() -> Int32

@_silgen_name("orbisonic_librespot_previous")
private func orbisonicLibrespotPrevious() -> Int32

@_silgen_name("orbisonic_librespot_next")
private func orbisonicLibrespotNext() -> Int32

@_silgen_name("orbisonic_librespot_seek")
private func orbisonicLibrespotSeek(_ positionMs: UInt32) -> Int32

@_silgen_name("orbisonic_librespot_set_volume")
private func orbisonicLibrespotSetVolume(_ volume: UInt16) -> Int32
#endif

struct SpotifyReceiverConfiguration: Equatable {
    var receiverName: String
    var loopbackDeviceName: String
    var loopbackDeviceUID: String
    var supportDirectoryURL: URL
    var cacheDirectoryURL: URL
    var logDirectoryURL: URL

    static func `default`(
        loopbackDevice: OrbisonicLoopbackDevice = .spotifyInput,
        fileManager: FileManager = .default
    ) -> SpotifyReceiverConfiguration {
        let supportDirectory = fileManager
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Orbisonic/SpotifyReceiver", isDirectory: true)

        return SpotifyReceiverConfiguration(
            receiverName: "Orbisonic Spotify",
            loopbackDeviceName: loopbackDevice.displayName,
            loopbackDeviceUID: loopbackDevice.deviceUID,
            supportDirectoryURL: supportDirectory,
            cacheDirectoryURL: supportDirectory.appendingPathComponent("Cache", isDirectory: true),
            logDirectoryURL: AppLogger.logDirectoryURL
        )
    }
}

struct SpotifyReceiverStatus: Equatable {
    enum State: String, Equatable {
        case notStarted
        case embeddedModuleUnavailable
        case waitingForConnection
        case restarting
        case running
        case failed
    }

    var state: State
    var message: String

    var isRunning: Bool {
        state == .waitingForConnection || state == .running
    }

    static let notStarted = SpotifyReceiverStatus(
        state: .notStarted,
        message: "Spotify Connect receiver has not started."
    )
}

struct SpotifyNowPlaying: Codable, Equatable, Sendable {
    var title: String?
    var album: String?
    var artists: [String]
    var albumArtists: [String]
    var uri: String?
    var durationMs: UInt32?
    var positionMs: UInt32?
    var isPlaying: Bool
    var isExplicit: Bool
    var popularity: UInt8?
    var trackNumber: UInt32?
    var discNumber: UInt32?
    var coverURL: String?
    var volume: UInt16?
    var shuffle: Bool?
    var repeatContext: Bool?
    var repeatTrack: Bool?
    var autoPlay: Bool?
    var clientName: String?
    var updatedAt: String?

    var displayTitle: String {
        title?.trimmedNilIfBlank ?? "Spotify"
    }

    var artistText: String {
        let text = artists.compactMap(\.trimmedNilIfBlank).joined(separator: ", ")
        return text.isEmpty ? "Spotify Connect" : text
    }

    var albumText: String {
        album?.trimmedNilIfBlank ?? "-"
    }

    var durationText: String {
        Self.timeText(milliseconds: durationMs)
    }

    var positionText: String {
        Self.timeText(milliseconds: positionMs)
    }

    var volumePercent: Int? {
        guard let volume else { return nil }
        return Int(round(Double(volume) / Double(UInt16.max) * 100.0))
    }

    private static func timeText(milliseconds: UInt32?) -> String {
        guard let milliseconds, milliseconds > 0 else { return "-" }
        let totalSeconds = Int(milliseconds / 1_000)
        return String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
    }
}

enum SpotifyReceiverControl {
    case playPause
    case previous
    case next
    case seek(positionMs: UInt32)
    case setVolume(percent: Int)
}

final class SpotifyReceiverClient {
    private(set) var configuration: SpotifyReceiverConfiguration
    private var started = false

    init(configuration: SpotifyReceiverConfiguration = .default()) {
        self.configuration = configuration
    }

    deinit {
        stop()
    }

    @discardableResult
    func start() -> SpotifyReceiverStatus {
        if started {
            return SpotifyReceiverStatus(
                state: .waitingForConnection,
                message: "Spotify Connect receiver is already advertising as \(configuration.receiverName)."
            )
        }

        do {
            try prepareRuntimeDirectories()
        } catch {
            let message = "Could not prepare Spotify receiver storage: \(error.localizedDescription)"
            AppLogger.shared.warning(category: "spotify-receiver", message)
            return SpotifyReceiverStatus(state: .failed, message: message)
        }

        #if ORBISONIC_ENABLE_EMBEDDED_LIBRESPOT
        if getenv("ORBISONIC_DISABLE_EMBEDDED_LIBRESPOT") != nil {
            let message = "Spotify Connect receiver is disabled for this process."
            AppLogger.shared.notice(category: "spotify-receiver", message)
            return SpotifyReceiverStatus(state: .embeddedModuleUnavailable, message: message)
        }

        let result = startEmbeddedLibrespot()
        if result == 0 || result == 1 {
            let message = "Spotify Connect receiver is advertising as \(configuration.receiverName)."
            started = true
            AppLogger.shared.notice(category: "spotify-receiver", message)
            return SpotifyReceiverStatus(state: .waitingForConnection, message: message)
        }

        let message = "Spotify Connect receiver failed to start. Rust status=\(result)."
        AppLogger.shared.warning(category: "spotify-receiver", message)
        return SpotifyReceiverStatus(state: .failed, message: message)
        #else
        let message = "Spotify Connect receiver is not linked into this build yet."
        AppLogger.shared.notice(category: "spotify-receiver", "\(message) Run scripts/build-embedded-librespot.sh after installing Rust 1.85 or newer.")
        return SpotifyReceiverStatus(state: .embeddedModuleUnavailable, message: message)
        #endif
    }

    func stop() {
        guard started else { return }
        #if ORBISONIC_ENABLE_EMBEDDED_LIBRESPOT
        _ = orbisonicLibrespotStop()
        #endif
        started = false
        AppLogger.shared.notice(category: "spotify-receiver", "Stopped Spotify Connect receiver.")
    }

    func readNowPlaying() -> SpotifyNowPlaying? {
        let stateURL = configuration.supportDirectoryURL.appendingPathComponent("state.json")
        guard let data = try? Data(contentsOf: stateURL) else { return nil }
        return try? JSONDecoder().decode(SpotifyNowPlaying.self, from: data)
    }

    @discardableResult
    func send(_ control: SpotifyReceiverControl) -> Bool {
        #if ORBISONIC_ENABLE_EMBEDDED_LIBRESPOT
        let code: Int32
        switch control {
        case .playPause:
            code = orbisonicLibrespotPlayPause()
        case .previous:
            code = orbisonicLibrespotPrevious()
        case .next:
            code = orbisonicLibrespotNext()
        case .seek(let positionMs):
            code = orbisonicLibrespotSeek(positionMs)
        case .setVolume(let percent):
            let clamped = min(max(percent, 0), 100)
            let volume = UInt16(round(Double(clamped) / 100.0 * Double(UInt16.max)))
            code = orbisonicLibrespotSetVolume(volume)
        }
        return code == 0
        #else
        return false
        #endif
    }

    private func prepareRuntimeDirectories() throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: configuration.supportDirectoryURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: configuration.cacheDirectoryURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: configuration.logDirectoryURL, withIntermediateDirectories: true)

        for fileName in ["SpotifyReceiver.out.log", "SpotifyReceiver.err.log"] {
            let url = configuration.logDirectoryURL.appendingPathComponent(fileName)
            if !fileManager.fileExists(atPath: url.path) {
                fileManager.createFile(atPath: url.path, contents: nil)
            }
        }
    }

    #if ORBISONIC_ENABLE_EMBEDDED_LIBRESPOT
    private func startEmbeddedLibrespot() -> Int32 {
        configuration.receiverName.withCString { receiverName in
            configuration.loopbackDeviceName.withCString { loopbackDeviceName in
                configuration.loopbackDeviceUID.withCString { loopbackDeviceUID in
                    configuration.supportDirectoryURL.path.withCString { supportDirectoryPath in
                        configuration.cacheDirectoryURL.path.withCString { cacheDirectoryPath in
                            configuration.logDirectoryURL.path.withCString { logDirectoryPath in
                                var ffiConfiguration = OrbisonicLibrespotConfig(
                                    receiverName: receiverName,
                                    loopbackDeviceName: loopbackDeviceName,
                                    loopbackDeviceUID: loopbackDeviceUID,
                                    supportDirectoryPath: supportDirectoryPath,
                                    cacheDirectoryPath: cacheDirectoryPath,
                                    logDirectoryPath: logDirectoryPath
                                )
                                return orbisonicLibrespotStart(&ffiConfiguration)
                            }
                        }
                    }
                }
            }
        }
    }
    #endif
}
