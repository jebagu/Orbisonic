import Foundation

struct NormalMonitorConversionLedger: Equatable, Sendable {
    static let rateToleranceHz: Double = 1

    let sourceSampleRate: Double?
    let inputRouteSampleRate: Double?
    let engineSampleRate: Double?
    let monitorRenderSampleRate: Double?
    let outputHardwareSampleRate: Double?
    let knownInternalSRCCount: Int
    let suspectedExternalSRC: Bool
    let suspectedFinalBoundarySRC: Bool
    let warningDescriptions: [String]

    init(
        sourceSampleRate: Double?,
        inputRouteSampleRate: Double? = nil,
        engineSampleRate: Double?,
        monitorRenderSampleRate: Double?,
        outputHardwareSampleRate: Double?,
        knownInternalSRCCount: Int = 0,
        sourceDescription: String = "source"
    ) {
        self.sourceSampleRate = Self.validRate(sourceSampleRate)
        self.inputRouteSampleRate = Self.validRate(inputRouteSampleRate)
        self.engineSampleRate = Self.validRate(engineSampleRate)
        self.monitorRenderSampleRate = Self.validRate(monitorRenderSampleRate)
        self.outputHardwareSampleRate = Self.validRate(outputHardwareSampleRate)
        self.knownInternalSRCCount = max(knownInternalSRCCount, 0)

        var warnings: [String] = []
        var externalSRC = false

        if self.sourceSampleRate == nil {
            warnings.append("\(sourceDescription) sample rate is unknown; source-to-input SRC cannot be ruled out.")
            externalSRC = true
        }

        if let sourceRate = self.sourceSampleRate,
           let inputRate = self.inputRouteSampleRate,
           !Self.ratesMatch(sourceRate, inputRate) {
            warnings.append(
                "\(sourceDescription) sample rate \(Self.formatRate(sourceRate)) differs from input route \(Self.formatRate(inputRate)); upstream or loopback SRC is suspected."
            )
            externalSRC = true
        }

        if let sourceRate = self.sourceSampleRate,
           self.inputRouteSampleRate == nil,
           let monitorRate = self.monitorRenderSampleRate,
           !Self.ratesMatch(sourceRate, monitorRate) {
            warnings.append(
                "\(sourceDescription) sample rate \(Self.formatRate(sourceRate)) differs from Normal Monitor render rate \(Self.formatRate(monitorRate)); AVAudioEngine SRC may be present."
            )
        }

        if let monitorRate = self.monitorRenderSampleRate,
           let engineRate = self.engineSampleRate,
           !Self.ratesMatch(monitorRate, engineRate) {
            warnings.append(
                "Normal Monitor render rate \(Self.formatRate(monitorRate)) differs from AVAudioEngine rate \(Self.formatRate(engineRate)); engine format negotiation may insert SRC."
            )
        }

        let boundaryRate = self.monitorRenderSampleRate ?? self.engineSampleRate
        let finalBoundarySRC: Bool
        if let boundaryRate,
           let outputRate = self.outputHardwareSampleRate,
           !Self.ratesMatch(boundaryRate, outputRate) {
            warnings.append(
                "Normal Monitor render rate \(Self.formatRate(boundaryRate)) differs from output hardware \(Self.formatRate(outputRate)); final boundary SRC is suspected."
            )
            finalBoundarySRC = true
        } else {
            finalBoundarySRC = false
        }

        suspectedExternalSRC = externalSRC
        suspectedFinalBoundarySRC = finalBoundarySRC
        warningDescriptions = warnings
    }

    static func localFile(
        sourceSampleRate: Double,
        engineSampleRate: Double,
        outputHardwareSampleRate: Double,
        monitorRenderSampleRate: Double? = nil,
        knownInternalSRCCount: Int = 0
    ) -> NormalMonitorConversionLedger {
        NormalMonitorConversionLedger(
            sourceSampleRate: sourceSampleRate,
            inputRouteSampleRate: nil,
            engineSampleRate: engineSampleRate,
            monitorRenderSampleRate: monitorRenderSampleRate ?? sourceSampleRate,
            outputHardwareSampleRate: outputHardwareSampleRate,
            knownInternalSRCCount: knownInternalSRCCount,
            sourceDescription: "Local file"
        )
    }

    static func liveLoopback(
        sourceSampleRate: Double?,
        inputRouteSampleRate: Double,
        engineSampleRate: Double,
        outputHardwareSampleRate: Double,
        monitorRenderSampleRate: Double? = nil,
        sourceDescription: String,
        knownInternalSRCCount: Int = 0
    ) -> NormalMonitorConversionLedger {
        NormalMonitorConversionLedger(
            sourceSampleRate: sourceSampleRate,
            inputRouteSampleRate: inputRouteSampleRate,
            engineSampleRate: engineSampleRate,
            monitorRenderSampleRate: monitorRenderSampleRate ?? inputRouteSampleRate,
            outputHardwareSampleRate: outputHardwareSampleRate,
            knownInternalSRCCount: knownInternalSRCCount,
            sourceDescription: sourceDescription
        )
    }

    static func ratesMatch(_ lhs: Double, _ rhs: Double) -> Bool {
        abs(lhs - rhs) <= rateToleranceHz
    }

    private static func validRate(_ sampleRate: Double?) -> Double? {
        guard let sampleRate,
              sampleRate.isFinite,
              sampleRate > 0
        else { return nil }
        return sampleRate
    }

    private static func formatRate(_ sampleRate: Double) -> String {
        let kilohertz = sampleRate / 1_000
        if abs(kilohertz.rounded() - kilohertz) < 0.01 {
            return "\(Int(kilohertz.rounded())) kHz"
        }
        return String(format: "%.1f kHz", kilohertz)
    }
}
