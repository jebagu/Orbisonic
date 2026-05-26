import Foundation

enum OrbisonicResourceLocator {
    private static let swiftPMResourceBundleName = "Orbisonic_Orbisonic.bundle"

    static func directory(containing filenames: [String], preferredSubdirectory: String? = nil) -> URL? {
        for directory in candidateDirectories(preferredSubdirectory: preferredSubdirectory) {
            let containsAllFiles = filenames.allSatisfy { filename in
                FileManager.default.fileExists(atPath: directory.appendingPathComponent(filename).path)
            }
            if containsAllFiles {
                return directory
            }
        }

        return nil
    }

    static func executableURL(named toolName: String, preferredSubdirectory: String? = nil) -> URL? {
        for directory in candidateDirectories(preferredSubdirectory: preferredSubdirectory) {
            let url = directory.appendingPathComponent(toolName)
            if FileManager.default.isExecutableFile(atPath: url.path) {
                return url
            }
        }

        return nil
    }

    private static func candidateDirectories(preferredSubdirectory: String?) -> [URL] {
        var directories: [URL] = []

        let baseURLs = packagedResourceBaseURLs() + developmentResourceBaseURLs()
        for baseURL in baseURLs {
            if let preferredSubdirectory {
                directories.append(baseURL.appendingPathComponent(preferredSubdirectory, isDirectory: true))
            }
            directories.append(baseURL)
        }

        return uniqueURLs(directories)
    }

    private static func packagedResourceBaseURLs() -> [URL] {
        [
            Bundle.main.resourceURL?.appendingPathComponent(swiftPMResourceBundleName, isDirectory: true),
            Bundle.main.resourceURL,
            Bundle.main.bundleURL.appendingPathComponent(swiftPMResourceBundleName, isDirectory: true)
        ].compactMap { $0 }
    }

    private static func developmentResourceBaseURLs() -> [URL] {
        let workingDirectoryURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        return [
            workingDirectoryURL
                .appendingPathComponent(".build/arm64-apple-macosx/debug", isDirectory: true)
                .appendingPathComponent(swiftPMResourceBundleName, isDirectory: true),
            workingDirectoryURL
                .appendingPathComponent(".build/debug", isDirectory: true)
                .appendingPathComponent(swiftPMResourceBundleName, isDirectory: true),
            workingDirectoryURL
                .appendingPathComponent("Sources/Orbisonic/Resources", isDirectory: true)
        ]
    }

    private static func uniqueURLs(_ urls: [URL]) -> [URL] {
        var seen = Set<String>()
        return urls.filter { url in
            let path = url.standardizedFileURL.path
            guard !seen.contains(path) else { return false }
            seen.insert(path)
            return true
        }
    }
}
