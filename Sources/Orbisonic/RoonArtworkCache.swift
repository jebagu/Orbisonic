import Foundation

struct RoonArtworkRequest: Equatable {
    let stableKey: String
    let imageKey: String
    let title: String
}

final class RoonArtworkCache {
    private let fileManager: FileManager
    private let directoryURL: URL

    init(fileManager: FileManager = .default, directoryURL: URL? = nil) {
        self.fileManager = fileManager
        self.directoryURL = directoryURL ?? Self.defaultDirectoryURL(fileManager: fileManager)
        try? fileManager.createDirectory(at: self.directoryURL, withIntermediateDirectories: true)
    }

    var directoryPath: String {
        directoryURL.path
    }

    func cachedURL(for stableKey: String) -> URL? {
        let url = cacheURL(for: stableKey)
        return fileManager.fileExists(atPath: url.path) ? url : nil
    }

    func store(_ data: Data, for stableKey: String) throws -> URL {
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let url = cacheURL(for: stableKey)
        try data.write(to: url, options: .atomic)
        return url
    }

    func cacheURL(for stableKey: String) -> URL {
        directoryURL.appendingPathComponent("\(Self.stableID(for: stableKey)).jpg", isDirectory: false)
    }

    private static func defaultDirectoryURL(fileManager: FileManager) -> URL {
        if let url = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Orbisonic/Roon Artwork", isDirectory: true) {
            try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
            return url
        }

        let fallbackURL = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Application Support/Orbisonic/Roon Artwork", isDirectory: true)
        try? fileManager.createDirectory(at: fallbackURL, withIntermediateDirectories: true)
        return fallbackURL
    }

    private static func stableID(for value: String) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return String(format: "%016llx", hash)
    }
}

