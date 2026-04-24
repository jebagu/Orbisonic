import Foundation

struct RoonNowPlaying: Equatable {
    let zoneName: String
    let qualityFormat: String
    let bufferStatus: String
    let state: String
    let positionText: String
    let durationText: String
    let title: String
    let artist: String
    let updatedText: String
    let rawLine: String

    var titleLine: String {
        artist.isEmpty ? title : "\(title) - \(artist)"
    }

    var progressLine: String {
        "\(state.capitalized) @ \(positionText)/\(durationText)"
    }

    var tidyFormatText: String {
        let renderedFormat = qualityFormat.components(separatedBy: "=>").last ?? qualityFormat
        return Self.tidyAudioFormat(renderedFormat)
    }

    var outputSampleRate: Double? {
        let renderedFormat = qualityFormat.components(separatedBy: "=>").last ?? qualityFormat
        guard let rateField = renderedFormat
            .split(separator: " ", omittingEmptySubsequences: true)
            .first(where: { $0.contains("/") })
        else { return nil }

        let rateText = rateField.split(separator: "/").last.map(String.init) ?? ""
        return Self.sampleRate(from: rateText)
    }

    private static func tidyAudioFormat(_ value: String) -> String {
        let cleaned = value
            .replacingOccurrences(of: "HighQuality,", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let fields = cleaned.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        guard let rateField = fields.first(where: { $0.contains("/") }) else {
            return cleaned
        }

        let pieces = rateField.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        let bitDepth: String?
        let sampleRate: String?

        if pieces.count >= 2 {
            bitDepth = pieces[0]
            sampleRate = pieces[1]
        } else {
            bitDepth = nil
            sampleRate = pieces.first
        }

        var parts: [String] = []
        if let sampleRate {
            parts.append(formatSampleRate(sampleRate))
        }
        if let bitDepth {
            parts.append("\(bitDepth)-bit")
        }
        if let channelField = fields.first(where: { $0.lowercased().hasSuffix("ch") }) {
            parts.append(channelField.lowercased())
        }

        return parts.isEmpty ? cleaned : parts.joined(separator: " / ")
    }

    private static func formatSampleRate(_ value: String) -> String {
        guard let hertz = sampleRate(from: value) else { return value }
        let kilohertz = hertz / 1_000

        if abs(kilohertz.rounded() - kilohertz) < 0.01 {
            return "\(Int(kilohertz.rounded())) kHz"
        }

        return String(format: "%.1f kHz", kilohertz)
    }

    private static func sampleRate(from value: String) -> Double? {
        guard let numericValue = Double(value) else { return nil }

        if numericValue >= 1_000 {
            return numericValue
        }

        switch Int(numericValue.rounded()) {
        case 44:
            return 44_100
        case 88:
            return 88_200
        case 176:
            return 176_400
        case 352:
            return 352_800
        default:
            return numericValue * 1_000
        }
    }
}

struct RoonSignalPath: Equatable {
    let sourceFormat: String
    let sourceChannelCount: Int?
    let channelMapping: String
    let device: String
    let output: String

    var sourceChannelText: String {
        guard let sourceChannelCount else {
            return "-"
        }

        return "\(sourceChannelCount) ch"
    }

    var isDownmixingToStereo: Bool {
        channelMapping.contains("→ 2.0") || channelMapping.contains("-> 2.0")
    }

    var statusText: String {
        if channelMapping.isEmpty {
            return "-"
        }

        return isDownmixingToStereo
            ? "\(channelMapping) - Roon is downmixing before BlackHole."
            : channelMapping
    }
}

final class RoonNowPlayingReader {
    static var defaultLogPath: String {
        "\(NSHomeDirectory())/Library/RoonServer/Logs/RoonServer_log.txt"
    }

    private let logPath: String

    init(logPath: String = RoonNowPlayingReader.defaultLogPath) {
        self.logPath = logPath
    }

    func readLatest() -> RoonNowPlaying? {
        guard let content = try? String(contentsOfFile: logPath, encoding: .utf8) else {
            return nil
        }

        return Self.parseLatest(in: content)
    }

    func readLatestSignalPath() -> RoonSignalPath? {
        guard let content = try? String(contentsOfFile: logPath, encoding: .utf8) else {
            return nil
        }

        return Self.parseLatestSignalPath(in: content)
    }

    static func parseLatest(in content: String) -> RoonNowPlaying? {
        for line in content.split(separator: "\n", omittingEmptySubsequences: true).reversed() {
            if let nowPlaying = parse(line: String(line)) {
                return nowPlaying
            }
        }

        return nil
    }

    static func parseLatestSignalPath(in content: String) -> RoonSignalPath? {
        let lines = content
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map(String.init)

        guard let signalPathIndex = lines.lastIndex(where: { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return trimmed.hasPrefix("Source Format=") || trimmed.hasPrefix("ChannelMapping ")
        }) else {
            return nil
        }

        let signalPathLine = lines[signalPathIndex].trimmingCharacters(in: .whitespacesAndNewlines)
        let sourceFormat = signalPathLine.hasPrefix("Source Format=")
            ? String(signalPathLine.dropFirst("Source Format=".count))
            : precedingValue(prefix: "Source Format=", before: signalPathIndex, in: lines)
        let channelMapping = signalPathLine.hasPrefix("ChannelMapping ")
            ? String(signalPathLine.dropFirst("ChannelMapping ".count))
            : followingValue(prefix: "ChannelMapping ", after: signalPathIndex, in: lines)
        let device = followingValue(prefix: "Raat Device=", after: signalPathIndex, in: lines)
        let output = followingValue(prefix: "Output ", after: signalPathIndex, in: lines)

        return RoonSignalPath(
            sourceFormat: sourceFormat,
            sourceChannelCount: sourceChannelCount(in: sourceFormat),
            channelMapping: channelMapping,
            device: device,
            output: output
        )
    }

    static func parse(line: String) -> RoonNowPlaying? {
        let bracketed = bracketFields(in: line)
        guard bracketed.count >= 4 else { return nil }

        let zoneName = bracketed[0]
        let qualityFormat = bracketed[1]
        let bufferStatus = bracketed[2]
        let transport = bracketed[3]

        guard transport.contains("@"), transport.contains("/") else {
            return nil
        }

        let titleArtist = trailingTextAfterBracketField(4, in: line)
        guard !titleArtist.isEmpty else { return nil }

        let transportParts = transport.components(separatedBy: "@")
        guard transportParts.count == 2 else { return nil }

        let state = transportParts[0].trimmingCharacters(in: .whitespacesAndNewlines)
        let timeParts = transportParts[1]
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: "/")
        guard timeParts.count == 2 else { return nil }

        let splitTitle = splitTitleAndArtist(titleArtist)

        return RoonNowPlaying(
            zoneName: zoneName,
            qualityFormat: qualityFormat,
            bufferStatus: bufferStatus,
            state: state,
            positionText: timeParts[0].trimmingCharacters(in: .whitespacesAndNewlines),
            durationText: timeParts[1].trimmingCharacters(in: .whitespacesAndNewlines),
            title: splitTitle.title,
            artist: splitTitle.artist,
            updatedText: timestampPrefix(in: line),
            rawLine: line
        )
    }

    private static func bracketFields(in line: String) -> [String] {
        var fields: [String] = []
        var searchStart = line.startIndex

        while let open = line[searchStart...].firstIndex(of: "["),
              let close = line[line.index(after: open)...].firstIndex(of: "]") {
            fields.append(String(line[line.index(after: open)..<close]))
            searchStart = line.index(after: close)
        }

        return fields
    }

    private static func trailingTextAfterBracketField(_ fieldCount: Int, in line: String) -> String {
        var searchStart = line.startIndex

        for _ in 0..<fieldCount {
            guard let open = line[searchStart...].firstIndex(of: "["),
                  let close = line[line.index(after: open)...].firstIndex(of: "]") else {
                return ""
            }

            searchStart = line.index(after: close)
        }

        return line[searchStart...].trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func splitTitleAndArtist(_ value: String) -> (title: String, artist: String) {
        guard let separatorRange = value.range(of: " - ", options: .backwards) else {
            return (value, "")
        }

        let title = value[..<separatorRange.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
        let artist = value[separatorRange.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
        return (title, artist)
    }

    private static func followingValue(prefix: String, after index: Int, in lines: [String]) -> String {
        let searchRange = lines.index(after: index)..<min(lines.count, index + 5)

        for lineIndex in searchRange {
            let line = lines[lineIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            if line.hasPrefix(prefix) {
                return String(line.dropFirst(prefix.count))
            }
        }

        return ""
    }

    private static func precedingValue(prefix: String, before index: Int, in lines: [String]) -> String {
        let lowerBound = max(0, index - 8)
        guard lowerBound < index else { return "" }

        for lineIndex in stride(from: index - 1, through: lowerBound, by: -1) {
            let line = lines[lineIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            if line.hasPrefix(prefix) {
                return String(line.dropFirst(prefix.count))
            }
        }

        return ""
    }

    private static func sourceChannelCount(in sourceFormat: String) -> Int? {
        guard let formatField = sourceFormat
            .split(separator: " ", omittingEmptySubsequences: true)
            .first(where: { $0.contains("/") })
        else { return nil }

        let pieces = formatField.split(separator: "/", omittingEmptySubsequences: true)
        guard pieces.count >= 3, let channelText = pieces.last else {
            return nil
        }

        return Int(channelText)
    }

    private static func timestampPrefix(in line: String) -> String {
        let fields = line.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
        guard fields.count >= 2 else { return "" }
        return "\(fields[0]) \(fields[1])"
    }
}
