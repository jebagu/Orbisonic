import AudioContracts
import AVFoundation
import Foundation

public struct LocalAssetProbeResult: Equatable, Hashable, Sendable {
    public let path: String
    public let durationFrames: Int64?
    public let durationSeconds: Double?
    public let sourceSampleRate: AudioSampleRate
    public let channelCount: Int
    public let codecDescription: String?
    public let channelLayout: AudioChannelLayoutDescriptor
    public let containerDescription: String?
    public let estimatedDecodedBytes: Int64?

    public init(
        path: String,
        durationFrames: Int64? = nil,
        durationSeconds: Double? = nil,
        sourceSampleRate: AudioSampleRate,
        channelCount: Int,
        codecDescription: String? = nil,
        channelLayout: AudioChannelLayoutDescriptor,
        containerDescription: String? = nil,
        estimatedDecodedBytes: Int64? = nil
    ) {
        self.path = path
        self.durationFrames = durationFrames
        self.durationSeconds = durationSeconds
        self.sourceSampleRate = sourceSampleRate
        self.channelCount = channelCount
        self.codecDescription = codecDescription
        self.channelLayout = channelLayout
        self.containerDescription = containerDescription
        self.estimatedDecodedBytes = estimatedDecodedBytes
    }

    public func isProductionReady(for sessionFormat: AudioSessionFormat) -> Bool {
        ProductionLocalAssetGate().isProductionReady(self, for: sessionFormat)
    }

    public func readiness(
        for sessionFormat: AudioSessionFormat,
        routeCapabilities: [DanteRouteCapability],
        isSessionRunning: Bool = true
    ) -> AssetReadiness {
        ProductionLocalAssetGate().readiness(
            for: self,
            sessionFormat: sessionFormat,
            routeCapabilities: routeCapabilities,
            isSessionRunning: isSessionRunning
        )
    }
}

public struct ProductionLocalAssetGate: Sendable {
    public init() {}

    public func isProductionReady(
        _ probe: LocalAssetProbeResult,
        for sessionFormat: AudioSessionFormat
    ) -> Bool {
        readiness(
            for: probe,
            sessionFormat: sessionFormat,
            routeCapabilities: [],
            isSessionRunning: true
        ) == .productionReady
    }

    public func readiness(
        for probe: LocalAssetProbeResult,
        sessionFormat: AudioSessionFormat,
        routeCapabilities: [DanteRouteCapability],
        isSessionRunning: Bool
    ) -> AssetReadiness {
        if let unsupportedReason = unsupportedReason(for: probe, sessionFormat: sessionFormat) {
            return .unsupported(reason: unsupportedReason)
        }

        guard !probe.sourceSampleRate.matches(sessionFormat.sampleRate) else {
            return .productionReady
        }

        let mismatchMessage = Self.sampleRateMismatchMessage(
            fileRate: probe.sourceSampleRate,
            sessionRate: sessionFormat.sampleRate
        )

        if !isSessionRunning,
           routeCapabilities.contains(where: { $0.supportsThirtyOneChannelProduction(at: probe.sourceSampleRate) }) {
            return .canRestartStoppedSessionAtFileRate(
                reason: mismatchMessage + " The selected Dante route can support a stopped-session rebuild at the file rate.",
                fileSampleRate: probe.sourceSampleRate
            )
        }

        return .requiresOfflineImport(
            reason: mismatchMessage,
            targetSampleRate: sessionFormat.sampleRate
        )
    }

    public func validateProductionAdmission(
        _ probe: LocalAssetProbeResult,
        sessionFormat: AudioSessionFormat
    ) throws {
        switch readiness(for: probe, sessionFormat: sessionFormat, routeCapabilities: [], isSessionRunning: true) {
        case .productionReady:
            return
        case .requiresOfflineImport:
            throw AudioError.localAssetRequiresManagedImport(sourceID: probe.path)
        case .canRestartStoppedSessionAtFileRate:
            throw AudioError.graphMutationRequiresStoppedSession
        case .unsupported(let reason), .desktopPreviewOnly(let reason):
            throw AudioError.invalidRenderGraphPlan(reason)
        }
    }

    public static func sampleRateMismatchMessage(
        fileRate: AudioSampleRate,
        sessionRate: AudioSampleRate
    ) -> String {
        "This file is \(formatSampleRate(fileRate)). Current Orbisonic Dante session is \(formatSampleRate(sessionRate)). Production playback requires matching sample rates. Convert a managed copy to \(formatSampleRate(sessionRate)), or restart the session at \(formatSampleRate(fileRate)) if the Dante route supports it."
    }

    public static func formatSampleRate(_ sampleRate: AudioSampleRate) -> String {
        let kilohertz = sampleRate.hertz / 1_000
        if abs(kilohertz.rounded() - kilohertz) <= 0.01 {
            return "\(Int(kilohertz.rounded())) kHz"
        }
        return String(format: "%.1f kHz", kilohertz)
    }

    private func unsupportedReason(
        for probe: LocalAssetProbeResult,
        sessionFormat: AudioSessionFormat
    ) -> String? {
        if !SourceDescriptor.sourceChannelLimit.contains(probe.channelCount) {
            return "Local file channel count \(probe.channelCount) is outside the supported 1...64 source range."
        }
        if probe.channelCount > sessionFormat.sourceChannelLimit {
            return "Local file channel count \(probe.channelCount) exceeds the session source limit of \(sessionFormat.sourceChannelLimit)."
        }
        if let error = probe.channelLayout.validationErrors(expectedChannelCount: probe.channelCount).first {
            return error.description
        }
        if let durationFrames = probe.durationFrames, durationFrames < 0 {
            return "Local file duration frames must not be negative."
        }
        return nil
    }
}

public struct ManagedAssetImporter {
    public static let managedAssetFormatDescription = "CAF Float32 PCM"

    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func probe(path: String) throws -> LocalAssetProbeResult {
        let url = URL(fileURLWithPath: path)
        guard fileManager.fileExists(atPath: url.path) else {
            throw AudioError.invalidRenderGraphPlan("Local asset does not exist: \(url.lastPathComponent).")
        }

        let file = try AVAudioFile(forReading: url)
        let processingFormat = file.processingFormat
        let sampleRateValue = processingFormat.sampleRate > 0
            ? processingFormat.sampleRate
            : file.fileFormat.sampleRate
        let sampleRate = try AudioSampleRate(hertz: sampleRateValue)
        let channelCount = Int(processingFormat.channelCount)
        let durationFrames = file.length >= 0 ? Int64(file.length) : nil
        let durationSeconds = durationFrames.flatMap { frames in
            sampleRate.hertz > 0 ? Double(frames) / sampleRate.hertz : nil
        }

        return LocalAssetProbeResult(
            path: path,
            durationFrames: durationFrames,
            durationSeconds: durationSeconds,
            sourceSampleRate: sampleRate,
            channelCount: channelCount,
            codecDescription: codecDescription(for: file, pathExtension: url.pathExtension),
            channelLayout: .fallbackLayout(channelCount: channelCount),
            containerDescription: url.pathExtension.trimmedNilIfBlank?.uppercased(),
            estimatedDecodedBytes: estimatedDecodedBytes(durationFrames: durationFrames, channelCount: channelCount)
        )
    }

    public func importAsset(
        originalPath: String,
        managedPath: String,
        managedAssetID: String,
        targetSessionFormat: AudioSessionFormat,
        declaredSourceSampleRate: AudioSampleRate? = nil,
        declaredSourceChannelCount: Int? = nil,
        declaredSourceLayout: AudioChannelLayoutDescriptor? = nil,
        durationFrames: Int64? = nil,
        codecDescription: String? = nil,
        containerDescription: String? = nil
    ) throws -> ManagedAssetDescriptor {
        try targetSessionFormat.validate()

        let sourceURL = URL(fileURLWithPath: originalPath)
        let managedURL = URL(fileURLWithPath: managedPath)
        guard !managedAssetID.isEmpty else {
            throw AudioError.invalidRenderGraphPlan("Managed asset ID is required.")
        }
        guard fileManager.fileExists(atPath: sourceURL.path) else {
            throw AudioError.invalidRenderGraphPlan("Local asset does not exist: \(sourceURL.lastPathComponent).")
        }

        let probe = try probe(path: originalPath)
        if let declaredSourceSampleRate,
           !declaredSourceSampleRate.matches(probe.sourceSampleRate) {
            throw AudioError.sampleRateMismatch(
                expected: declaredSourceSampleRate,
                actual: probe.sourceSampleRate,
                context: "local asset probe"
            )
        }
        if let declaredSourceChannelCount,
           declaredSourceChannelCount != probe.channelCount {
            throw AudioError.layoutChannelCountMismatch(
                expected: declaredSourceChannelCount,
                actual: probe.channelCount
            )
        }

        if let declaredSourceLayout,
           let error = declaredSourceLayout.validationErrors(expectedChannelCount: probe.channelCount).first {
            throw error
        }

        try fileManager.createDirectory(
            at: managedURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if fileManager.fileExists(atPath: managedURL.path) {
            try fileManager.removeItem(at: managedURL)
        }

        let sourceFile = try AVAudioFile(forReading: sourceURL)
        let sourceFormat = sourceFile.processingFormat
        guard sourceFile.length <= AVAudioFramePosition(UInt32.max) else {
            throw AudioError.invalidRenderGraphPlan("Managed import currently supports files up to UInt32.max frames.")
        }
        guard let sourceBuffer = AVAudioPCMBuffer(
            pcmFormat: sourceFormat,
            frameCapacity: AVAudioFrameCount(sourceFile.length)
        ) else {
            throw AudioError.invalidRenderGraphPlan("Unable to allocate source buffer for managed import.")
        }
        try sourceFile.read(into: sourceBuffer)

        let outputFormat = try makeOutputFormat(
            sourceFormat: sourceFormat,
            targetSampleRate: targetSessionFormat.sampleRate
        )
        let outputFrameCapacity = outputFrameCapacity(
            sourceFrames: sourceBuffer.frameLength,
            sourceSampleRate: sourceFormat.sampleRate,
            targetSampleRate: targetSessionFormat.sampleRate
        )
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: outputFrameCapacity) else {
            throw AudioError.invalidRenderGraphPlan("Unable to allocate managed output buffer.")
        }

        guard let converter = AVAudioConverter(from: sourceFormat, to: outputFormat) else {
            throw AudioError.invalidRenderGraphPlan("Unable to create offline managed asset converter.")
        }

        var suppliedInput = false
        var conversionError: NSError?
        let status = converter.convert(to: outputBuffer, error: &conversionError) { _, outStatus in
            if suppliedInput {
                outStatus.pointee = .endOfStream
                return nil
            }

            suppliedInput = true
            outStatus.pointee = .haveData
            return sourceBuffer
        }

        if status == .error || conversionError != nil {
            throw AudioError.invalidRenderGraphPlan(
                "Offline managed asset conversion failed: \(conversionError?.localizedDescription ?? "unknown converter error")."
            )
        }
        guard outputBuffer.frameLength > 0 else {
            throw AudioError.invalidRenderGraphPlan("Offline managed asset conversion produced no audio frames.")
        }

        let outputFile = try AVAudioFile(
            forWriting: managedURL,
            settings: outputFormat.settings,
            commonFormat: outputFormat.commonFormat,
            interleaved: outputFormat.isInterleaved
        )
        try outputFile.write(from: outputBuffer)

        let sourceLayout = declaredSourceLayout ?? probe.channelLayout
        let finalDurationFrames = Int64(outputBuffer.frameLength)
        return ManagedAssetDescriptor(
            id: managedAssetID,
            originalPath: originalPath,
            managedPath: managedPath,
            originalSampleRate: probe.sourceSampleRate,
            managedSampleRate: targetSessionFormat.sampleRate,
            channelCount: probe.channelCount,
            layout: sourceLayout,
            codecDescription: codecDescription ?? probe.codecDescription,
            containerDescription: containerDescription ?? Self.managedAssetFormatDescription,
            durationFrames: finalDurationFrames,
            conversionLedger: conversionLedger(
                source: probe,
                sessionFormat: targetSessionFormat,
                managedPath: managedPath
            ),
            createdAtUnixTimeSeconds: Date().timeIntervalSince1970
        )
    }

    private func makeOutputFormat(
        sourceFormat: AVAudioFormat,
        targetSampleRate: AudioSampleRate
    ) throws -> AVAudioFormat {
        let channelCount = sourceFormat.channelCount
        if let channelLayout = sourceFormat.channelLayout {
            let format = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: targetSampleRate.hertz,
                interleaved: true,
                channelLayout: channelLayout
            )
            if format.channelCount == channelCount {
                return format
            }
        }

        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: targetSampleRate.hertz,
            channels: channelCount,
            interleaved: true
        ) else {
            throw AudioError.invalidRenderGraphPlan("Unable to create managed CAF Float32 PCM format.")
        }
        return format
    }

    private func outputFrameCapacity(
        sourceFrames: AVAudioFrameCount,
        sourceSampleRate: Double,
        targetSampleRate: AudioSampleRate
    ) -> AVAudioFrameCount {
        guard sourceSampleRate.isFinite, sourceSampleRate > 0 else {
            return sourceFrames
        }

        let ratio = targetSampleRate.hertz / sourceSampleRate
        let estimated = ceil(Double(sourceFrames) * ratio) + 4_096
        return AVAudioFrameCount(min(max(estimated, 1), Double(UInt32.max)))
    }

    private func conversionLedger(
        source: LocalAssetProbeResult,
        sessionFormat: AudioSessionFormat,
        managedPath: String
    ) -> ConversionLedger {
        var allowedConversions: [AllowedAudioConversion] = [
            .codecDecodeToPCM,
            .integerPCMToFloat32,
            .interleavedToDeinterleaved,
            .layoutMetadataNormalization
        ]
        if !source.sourceSampleRate.matches(sessionFormat.sampleRate) {
            allowedConversions.append(.offlineManagedSampleRateConversion)
        }

        return ConversionLedger(
            sessionSampleRate: sessionFormat.sampleRate,
            sourceOriginalDescription: "path=\(source.path) sampleRate=\(source.sourceSampleRate.hertz) channels=\(source.channelCount) codec=\(source.codecDescription ?? "unknown") container=\(source.containerDescription ?? "unknown")",
            sourceCanonicalDescription: "managedPath=\(managedPath) format=\(Self.managedAssetFormatDescription) sampleRate=\(sessionFormat.sampleRate.hertz) channels=\(source.channelCount)",
            allowedConversions: allowedConversions,
            forbiddenConversionsObserved: [],
            desktopOutputDescription: "desktopSampleRate=\(sessionFormat.desktop.sampleRate.hertz) channels=\(sessionFormat.desktop.channelCount)",
            danteOutputDescription: "danteSampleRate=\(sessionFormat.dante.sampleRate.hertz) logicalChannels=\(sessionFormat.dante.logicalChannelCount) physicalChannels=\(sessionFormat.dante.physicalChannelCount)"
        )
    }

    private func estimatedDecodedBytes(durationFrames: Int64?, channelCount: Int) -> Int64? {
        guard let durationFrames,
              durationFrames >= 0,
              channelCount > 0
        else { return nil }

        let estimate = Double(durationFrames) * Double(channelCount) * Double(MemoryLayout<Float>.size)
        guard estimate.isFinite,
              estimate >= 0,
              estimate <= Double(Int64.max)
        else { return nil }

        return Int64(estimate.rounded(.up))
    }

    private func codecDescription(for file: AVAudioFile, pathExtension: String) -> String {
        if file.fileFormat.commonFormat == .pcmFormatFloat32 || file.fileFormat.commonFormat == .pcmFormatInt16 {
            return "PCM"
        }
        return pathExtension.trimmedNilIfBlank?.uppercased() ?? "audio"
    }
}

private extension String {
    var trimmedNilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
