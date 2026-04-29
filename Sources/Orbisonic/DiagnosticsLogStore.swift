import Foundation

struct DiagnosticsLogReadResult: Sendable, Equatable {
    let lines: [String]
    let bytesRead: Int
    let fileSizeBytes: UInt64
    let elapsedMilliseconds: Double
}

actor DiagnosticsLogStore {
    static let defaultMaxBytes = 256 * 1024
    static let defaultMaxLines = 500

    private let logFileURL: URL
    private let interestingMarkers: [String]

    init(
        logFileURL: URL = AppLogger.logFileURL,
        interestingMarkers: [String] = ["[WARNING]", "[ERROR]"]
    ) {
        self.logFileURL = logFileURL
        self.interestingMarkers = interestingMarkers
    }

    func readRecentInterestingLines(
        maxBytes: Int = DiagnosticsLogStore.defaultMaxBytes,
        maxLines: Int = DiagnosticsLogStore.defaultMaxLines
    ) async -> [String] {
        await readRecentInterestingLinesWithMetrics(maxBytes: maxBytes, maxLines: maxLines).lines
    }

    func readRecentInterestingLinesWithMetrics(
        maxBytes: Int = DiagnosticsLogStore.defaultMaxBytes,
        maxLines: Int = DiagnosticsLogStore.defaultMaxLines
    ) async -> DiagnosticsLogReadResult {
        let start = DispatchTime.now().uptimeNanoseconds
        let byteLimit = max(0, maxBytes)
        let lineLimit = max(0, maxLines)
        guard byteLimit > 0, lineLimit > 0 else {
            return Self.result(lines: [], bytesRead: 0, fileSizeBytes: 0, start: start)
        }

        guard let fileHandle = try? FileHandle(forReadingFrom: logFileURL) else {
            return Self.result(lines: [], bytesRead: 0, fileSizeBytes: 0, start: start)
        }
        defer {
            try? fileHandle.close()
        }

        let fileSize = (try? fileHandle.seekToEnd()) ?? 0
        guard fileSize > 0 else {
            return Self.result(lines: [], bytesRead: 0, fileSizeBytes: fileSize, start: start)
        }

        let bytesToRead = min(UInt64(byteLimit), fileSize)
        let offset = fileSize - bytesToRead
        try? fileHandle.seek(toOffset: offset)

        let data = fileHandle.readData(ofLength: Int(bytesToRead))
        guard !data.isEmpty else {
            return Self.result(lines: [], bytesRead: 0, fileSizeBytes: fileSize, start: start)
        }

        var lines = String(decoding: data, as: UTF8.self)
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map(String.init)

        if offset > 0, !lines.isEmpty {
            lines.removeFirst()
        }

        let recentMatches = lines
            .reversed()
            .lazy
            .filter { line in
                self.interestingMarkers.contains { marker in
                    line.contains(marker)
                }
            }
            .prefix(lineLimit)

        return Self.result(
            lines: Array(recentMatches.reversed()),
            bytesRead: data.count,
            fileSizeBytes: fileSize,
            start: start
        )
    }

    private static func result(
        lines: [String],
        bytesRead: Int,
        fileSizeBytes: UInt64,
        start: UInt64
    ) -> DiagnosticsLogReadResult {
        DiagnosticsLogReadResult(
            lines: lines,
            bytesRead: bytesRead,
            fileSizeBytes: fileSizeBytes,
            elapsedMilliseconds: Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000.0
        )
    }
}
