import AudioContracts
import Foundation

public struct ImmutableMatrix: Equatable, Hashable, Sendable {
    public let inputCount: Int
    public let outputCount: Int

    private let inputMajorGains: [Double]

    public init(
        inputCount: Int,
        outputCount: Int,
        inputMajorGains: [Double]
    ) throws {
        guard inputCount > 0 else {
            throw AudioError.invalidRenderGraphPlan("Matrix input count must be positive.")
        }
        guard outputCount > 0 else {
            throw AudioError.invalidRenderGraphPlan("Matrix output count must be positive.")
        }
        guard inputMajorGains.count == inputCount * outputCount else {
            throw AudioError.invalidRenderGraphPlan("Matrix storage does not match input/output dimensions.")
        }
        guard inputMajorGains.allSatisfy(\.isFinite) else {
            throw AudioError.invalidRenderGraphPlan("Matrix gains must be finite.")
        }
        self.inputCount = inputCount
        self.outputCount = outputCount
        self.inputMajorGains = inputMajorGains
    }

    public init(inputRows: [[Double]]) throws {
        guard let outputCount = inputRows.first?.count, outputCount > 0 else {
            throw AudioError.invalidRenderGraphPlan("Matrix requires at least one output.")
        }
        guard !inputRows.isEmpty else {
            throw AudioError.invalidRenderGraphPlan("Matrix requires at least one input.")
        }
        guard inputRows.allSatisfy({ $0.count == outputCount }) else {
            throw AudioError.invalidRenderGraphPlan("Matrix rows must all have the same output count.")
        }
        try self.init(
            inputCount: inputRows.count,
            outputCount: outputCount,
            inputMajorGains: inputRows.flatMap { $0 }
        )
    }

    public func gain(input: Int, output: Int) -> Double {
        guard input >= 0, input < inputCount, output >= 0, output < outputCount else {
            return 0
        }
        return inputMajorGains[input * outputCount + output]
    }

    public func gainsCopy() -> [[Double]] {
        (0..<inputCount).map { input in
            (0..<outputCount).map { output in
                gain(input: input, output: output)
            }
        }
    }

    public func isOutputSilent(_ output: Int, tolerance: Double = 0.000_001) -> Bool {
        guard output >= 0, output < outputCount else { return false }
        for input in 0..<inputCount where abs(gain(input: input, output: output)) > tolerance {
            return false
        }
        return true
    }
}

public enum DesktopLFEPolicy: String, CaseIterable, Equatable, Hashable, Sendable {
    case muted
}

public struct DesktopDownmixPlan: Equatable, Hashable, Sendable {
    public let outputChannelCount: Int
    public let sessionSampleRate: AudioSampleRate
    public let sourceLayout: AudioChannelLayoutDescriptor
    public let lfePolicy: DesktopLFEPolicy
    public let coefficients: ImmutableMatrix
    public let headroomGain: LinearGain

    public init(
        outputChannelCount: Int = 2,
        sessionSampleRate: AudioSampleRate,
        sourceLayout: AudioChannelLayoutDescriptor,
        lfePolicy: DesktopLFEPolicy = .muted,
        coefficients: ImmutableMatrix,
        headroomGain: LinearGain
    ) {
        self.outputChannelCount = outputChannelCount
        self.sessionSampleRate = sessionSampleRate
        self.sourceLayout = sourceLayout
        self.lfePolicy = lfePolicy
        self.coefficients = coefficients
        self.headroomGain = headroomGain
    }

    public static func referenceStereo(
        sessionSampleRate: AudioSampleRate,
        sourceLayout: AudioChannelLayoutDescriptor
    ) throws -> DesktopDownmixPlan {
        let headroom = sourceLayout.channelCount > 2
            ? ReferenceStereoDownmixPolicy.multichannelHeadroom
            : 1.0
        let matrixRows = sourceLayout.roles.enumerated().map { index, role in
            ReferenceStereoDownmixPolicy.coefficients(
                for: role,
                inputIndex: index,
                sourceChannelCount: sourceLayout.channelCount
            )
        }

        return DesktopDownmixPlan(
            sessionSampleRate: sessionSampleRate,
            sourceLayout: sourceLayout,
            coefficients: try ImmutableMatrix(inputRows: matrixRows),
            headroomGain: try LinearGain(headroom)
        )
    }
}

public struct DanteRenderPlan: Equatable, Hashable, Sendable {
    public static let logicalOutputCount = 31
    public static let fullRangeOutputCount = 30
    public static let lfeOutputIndex = 30
    public static let reservedPhysicalOutputIndex = 31

    public let logicalOutputCount: Int
    public let physicalOutputCount: Int
    public let fullRangeOutputCount: Int
    public let lfeOutputIndex: Int
    public let channel32Reserved: Bool
    public let sessionSampleRate: AudioSampleRate
    public let sourceLayout: AudioChannelLayoutDescriptor
    public let renderMode: RenderMode
    public let coefficients: ImmutableMatrix

    public init(
        logicalOutputCount: Int = DanteRenderPlan.logicalOutputCount,
        physicalOutputCount: Int,
        fullRangeOutputCount: Int = DanteRenderPlan.fullRangeOutputCount,
        lfeOutputIndex: Int = DanteRenderPlan.lfeOutputIndex,
        channel32Reserved: Bool? = nil,
        sessionSampleRate: AudioSampleRate,
        sourceLayout: AudioChannelLayoutDescriptor,
        renderMode: RenderMode,
        coefficients: ImmutableMatrix
    ) {
        self.logicalOutputCount = logicalOutputCount
        self.physicalOutputCount = physicalOutputCount
        self.fullRangeOutputCount = fullRangeOutputCount
        self.lfeOutputIndex = lfeOutputIndex
        self.channel32Reserved = channel32Reserved ?? (physicalOutputCount == 32)
        self.sessionSampleRate = sessionSampleRate
        self.sourceLayout = sourceLayout
        self.renderMode = renderMode
        self.coefficients = coefficients
    }

    public var isPhysicalChannel32Silent: Bool {
        guard physicalOutputCount == 32 else { return true }
        return coefficients.isOutputSilent(Self.reservedPhysicalOutputIndex)
    }

    public static func make(
        sessionFormat: AudioSessionFormat,
        source: SourceDescriptor,
        renderMode requestedMode: RenderMode
    ) throws -> DanteRenderPlan {
        let resolvedMode = PureAudioDanteMatrixPolicy.resolvedMode(
            requestedMode,
            sourceChannelCount: source.channelCount
        )
        let coefficients = try PureAudioDanteMatrixPolicy.matrix(
            sourceLayout: source.layout,
            renderMode: resolvedMode,
            physicalOutputCount: sessionFormat.dante.physicalChannelCount
        )

        return DanteRenderPlan(
            physicalOutputCount: sessionFormat.dante.physicalChannelCount,
            sessionSampleRate: sessionFormat.sampleRate,
            sourceLayout: source.layout,
            renderMode: resolvedMode,
            coefficients: coefficients
        )
    }
}

public struct GainPlan: Equatable, Hashable, Sendable {
    public let sourceTrim: LinearGain
    public let desktopMonitorGain: LinearGain
    public let danteOutputGain: LinearGain
    public let meterCalibrationGain: LinearGain
    public let testToneCalibrationGain: LinearGain

    public init(
        sourceTrim: LinearGain = .unity,
        desktopMonitorGain: LinearGain = .unity,
        danteOutputGain: LinearGain = .unity,
        meterCalibrationGain: LinearGain = .unity,
        testToneCalibrationGain: LinearGain = .unity
    ) {
        self.sourceTrim = sourceTrim
        self.desktopMonitorGain = desktopMonitorGain
        self.danteOutputGain = danteOutputGain
        self.meterCalibrationGain = meterCalibrationGain
        self.testToneCalibrationGain = testToneCalibrationGain
    }

    public var audibleGains: [LinearGain] {
        [sourceTrim, desktopMonitorGain, danteOutputGain, testToneCalibrationGain]
    }

    public var allGains: [LinearGain] {
        audibleGains + [meterCalibrationGain]
    }
}

public struct LimiterPlan: Equatable, Hashable, Sendable {
    public let isEnabled: Bool
    public let ceilingDBFS: Double

    public init(isEnabled: Bool, ceilingDBFS: Double) {
        self.isEnabled = isEnabled
        self.ceilingDBFS = ceilingDBFS
    }
}

public enum MeterCopyPoint: String, CaseIterable, Equatable, Hashable, Sendable {
    case inputSourceBus
    case desktopPostRenderPreOutputGain
    case dantePostRenderPreOutputGain
}

public struct MeterPlan: Equatable, Hashable, Sendable {
    public let copyPoints: Set<MeterCopyPoint>
    public let inputMeterChannelCount: Int
    public let desktopMeterChannelCount: Int
    public let danteMeterChannelCount: Int
    public let isCopyOnly: Bool

    public init(
        copyPoints: Set<MeterCopyPoint> = Set(MeterCopyPoint.allCases),
        inputMeterChannelCount: Int,
        desktopMeterChannelCount: Int = 2,
        danteMeterChannelCount: Int = 31,
        isCopyOnly: Bool = true
    ) {
        self.copyPoints = copyPoints
        self.inputMeterChannelCount = inputMeterChannelCount
        self.desktopMeterChannelCount = desktopMeterChannelCount
        self.danteMeterChannelCount = danteMeterChannelCount
        self.isCopyOnly = isCopyOnly
    }
}

public struct RenderGraphPlan: Equatable, Hashable, Sendable {
    public let version: UInt64
    public let sessionFormat: AudioSessionFormat
    public let source: SourceDescriptor
    public let renderMode: RenderMode
    public let desktopDownmix: DesktopDownmixPlan
    public let danteRenderer: DanteRenderPlan
    public let gainPlan: GainPlan
    public let limiterPlan: LimiterPlan?
    public let meterPlan: MeterPlan
    public let conversionLedger: ConversionLedger
    public let validationMessages: [String]
    public let createdAtUnixTimeSeconds: Double?

    public init(
        version: UInt64,
        sessionFormat: AudioSessionFormat,
        source: SourceDescriptor,
        renderMode: RenderMode,
        desktopDownmix: DesktopDownmixPlan,
        danteRenderer: DanteRenderPlan,
        gainPlan: GainPlan = GainPlan(),
        limiterPlan: LimiterPlan? = nil,
        meterPlan: MeterPlan,
        conversionLedger: ConversionLedger,
        validationMessages: [String] = [],
        createdAtUnixTimeSeconds: Double? = nil
    ) {
        self.version = version
        self.sessionFormat = sessionFormat
        self.source = source
        self.renderMode = renderMode
        self.desktopDownmix = desktopDownmix
        self.danteRenderer = danteRenderer
        self.gainPlan = gainPlan
        self.limiterPlan = limiterPlan
        self.meterPlan = meterPlan
        self.conversionLedger = conversionLedger
        self.validationMessages = validationMessages
        self.createdAtUnixTimeSeconds = createdAtUnixTimeSeconds
    }
}

public struct RenderGraphPlanRequest: Equatable, Hashable, Sendable {
    public let version: UInt64
    public let sessionFormat: AudioSessionFormat
    public let source: SourceDescriptor
    public let renderMode: RenderMode
    public let gainPlan: GainPlan
    public let limiterPlan: LimiterPlan?
    public let conversionLedger: ConversionLedger?
    public let validationMessages: [String]
    public let createdAtUnixTimeSeconds: Double?

    public init(
        version: UInt64,
        sessionFormat: AudioSessionFormat,
        source: SourceDescriptor,
        renderMode: RenderMode = .automatic,
        gainPlan: GainPlan = GainPlan(),
        limiterPlan: LimiterPlan? = nil,
        conversionLedger: ConversionLedger? = nil,
        validationMessages: [String] = [],
        createdAtUnixTimeSeconds: Double? = Date().timeIntervalSince1970
    ) {
        self.version = version
        self.sessionFormat = sessionFormat
        self.source = source
        self.renderMode = renderMode
        self.gainPlan = gainPlan
        self.limiterPlan = limiterPlan
        self.conversionLedger = conversionLedger
        self.validationMessages = validationMessages
        self.createdAtUnixTimeSeconds = createdAtUnixTimeSeconds
    }
}

public struct RenderGraphPlanner: Sendable {
    private let validator: PlanValidator

    public init(validator: PlanValidator = PlanValidator()) {
        self.validator = validator
    }

    public func makeValidatedPlan(_ request: RenderGraphPlanRequest) throws -> RenderGraphPlan {
        let desktop = try DesktopDownmixPlan.referenceStereo(
            sessionSampleRate: request.sessionFormat.sampleRate,
            sourceLayout: request.source.layout
        )
        let dante = try DanteRenderPlan.make(
            sessionFormat: request.sessionFormat,
            source: request.source,
            renderMode: request.renderMode
        )
        let plan = RenderGraphPlan(
            version: request.version,
            sessionFormat: request.sessionFormat,
            source: request.source,
            renderMode: dante.renderMode,
            desktopDownmix: desktop,
            danteRenderer: dante,
            gainPlan: request.gainPlan,
            limiterPlan: request.limiterPlan,
            meterPlan: MeterPlan(
                inputMeterChannelCount: request.source.channelCount,
                desktopMeterChannelCount: 2,
                danteMeterChannelCount: DanteRenderPlan.logicalOutputCount
            ),
            conversionLedger: request.conversionLedger ?? Self.defaultLedger(
                sessionFormat: request.sessionFormat,
                source: request.source
            ),
            validationMessages: request.validationMessages,
            createdAtUnixTimeSeconds: request.createdAtUnixTimeSeconds
        )
        try validator.validateOrThrow(plan)
        return plan
    }

    public static func defaultLedger(
        sessionFormat: AudioSessionFormat,
        source: SourceDescriptor
    ) -> ConversionLedger {
        ConversionLedger(
            sessionSampleRate: sessionFormat.sampleRate,
            sourceOriginalDescription: "\(source.kind.rawValue) \(source.sampleRate.hertz) Hz \(source.channelCount)ch",
            sourceCanonicalDescription: "Float32 non-interleaved PCM \(sessionFormat.sampleRate.hertz) Hz \(source.channelCount)ch",
            allowedConversions: [
                .codecDecodeToPCM,
                .integerPCMToFloat32,
                .interleavedToDeinterleaved,
                .layoutMetadataNormalization
            ],
            forbiddenConversionsObserved: [],
            desktopOutputDescription: "desktop stereo \(sessionFormat.sampleRate.hertz) Hz",
            danteOutputDescription: "Dante \(sessionFormat.dante.logicalChannelCount)-channel logical \(sessionFormat.sampleRate.hertz) Hz"
        )
    }
}

public struct PlanValidator: Sendable {
    public init() {}

    public func validate(_ plan: RenderGraphPlan) -> [AudioError] {
        var errors: [AudioError] = []
        errors.append(contentsOf: plan.sessionFormat.validationErrors())
        errors.append(contentsOf: plan.source.validationErrors(sessionFormat: plan.sessionFormat))
        errors.append(contentsOf: validateDesktop(plan))
        errors.append(contentsOf: validateDante(plan))
        errors.append(contentsOf: validateGains(plan))
        errors.append(contentsOf: validateLimiter(plan.limiterPlan))
        errors.append(contentsOf: validateMeters(plan))
        errors.append(contentsOf: validateLedger(plan))
        if plan.version == 0 {
            errors.append(.invalidRenderGraphPlan("Plan version must be positive."))
        }
        return errors
    }

    public func validateOrThrow(_ plan: RenderGraphPlan) throws {
        if let error = validate(plan).first {
            throw error
        }
    }

    private func validateDesktop(_ plan: RenderGraphPlan) -> [AudioError] {
        var errors: [AudioError] = []
        if plan.desktopDownmix.outputChannelCount != 2 {
            errors.append(.desktopRouteInsufficientChannels(required: 2, actual: plan.desktopDownmix.outputChannelCount))
        }
        if plan.desktopDownmix.coefficients.inputCount != plan.source.channelCount {
            errors.append(.invalidRenderGraphPlan("Desktop matrix input count must match source channel count."))
        }
        if plan.desktopDownmix.coefficients.outputCount != 2 {
            errors.append(.desktopRouteInsufficientChannels(required: 2, actual: plan.desktopDownmix.coefficients.outputCount))
        }
        if !plan.desktopDownmix.sessionSampleRate.matches(plan.sessionFormat.sampleRate) {
            errors.append(
                .sampleRateMismatch(
                    expected: plan.sessionFormat.sampleRate,
                    actual: plan.desktopDownmix.sessionSampleRate,
                    context: "desktop downmix"
                )
            )
        }
        errors.append(contentsOf: plan.desktopDownmix.sourceLayout.validationErrors(expectedChannelCount: plan.source.channelCount))
        return errors
    }

    private func validateDante(_ plan: RenderGraphPlan) -> [AudioError] {
        var errors: [AudioError] = []
        if plan.danteRenderer.logicalOutputCount != DanteRenderPlan.logicalOutputCount {
            errors.append(.invalidRenderGraphPlan("Dante logical output count must be 31."))
        }
        if plan.danteRenderer.fullRangeOutputCount != DanteRenderPlan.fullRangeOutputCount {
            errors.append(.invalidRenderGraphPlan("Dante full-range output count must be 30."))
        }
        if plan.danteRenderer.lfeOutputIndex != DanteRenderPlan.lfeOutputIndex {
            errors.append(.invalidRenderGraphPlan("Dante LFE output must be channel 31."))
        }
        if plan.danteRenderer.physicalOutputCount < 31 {
            errors.append(.danteRouteInsufficientChannels(required: 31, actual: plan.danteRenderer.physicalOutputCount))
        } else if plan.danteRenderer.physicalOutputCount > 32 {
            errors.append(.invalidRenderGraphPlan("Dante physical output count must be 31 or 32."))
        }
        if plan.danteRenderer.coefficients.inputCount != plan.source.channelCount {
            errors.append(.invalidRenderGraphPlan("Dante matrix input count must match source channel count."))
        }
        if plan.danteRenderer.coefficients.outputCount < DanteRenderPlan.logicalOutputCount {
            errors.append(.danteRouteInsufficientChannels(required: 31, actual: plan.danteRenderer.coefficients.outputCount))
        }
        if plan.danteRenderer.coefficients.outputCount != plan.danteRenderer.physicalOutputCount {
            errors.append(.invalidRenderGraphPlan("Dante matrix output count must match physical output count."))
        }
        if plan.danteRenderer.physicalOutputCount == 32 {
            if !plan.danteRenderer.channel32Reserved {
                errors.append(.invalidRenderGraphPlan("Dante physical channel 32 must be reserved."))
            }
            if !plan.danteRenderer.isPhysicalChannel32Silent {
                errors.append(.invalidRenderGraphPlan("Dante physical channel 32 must be silent."))
            }
        }
        if !plan.danteRenderer.sessionSampleRate.matches(plan.sessionFormat.sampleRate) {
            errors.append(
                .sampleRateMismatch(
                    expected: plan.sessionFormat.sampleRate,
                    actual: plan.danteRenderer.sessionSampleRate,
                    context: "Dante render"
                )
            )
        }
        errors.append(contentsOf: plan.danteRenderer.sourceLayout.validationErrors(expectedChannelCount: plan.source.channelCount))
        return errors
    }

    private func validateGains(_ plan: RenderGraphPlan) -> [AudioError] {
        plan.gainPlan.allGains.allSatisfy { $0.value.isFinite }
            ? []
            : [.invalidRenderGraphPlan("Gain values must be finite.")]
    }

    private func validateLimiter(_ limiterPlan: LimiterPlan?) -> [AudioError] {
        guard let limiterPlan else { return [] }
        return limiterPlan.ceilingDBFS.isFinite
            ? []
            : [.invalidRenderGraphPlan("Limiter ceiling must be finite.")]
    }

    private func validateMeters(_ plan: RenderGraphPlan) -> [AudioError] {
        var errors: [AudioError] = []
        if !plan.meterPlan.isCopyOnly {
            errors.append(.invalidRenderGraphPlan("Meter plan must be copy-only."))
        }
        if plan.meterPlan.inputMeterChannelCount != plan.source.channelCount {
            errors.append(.invalidRenderGraphPlan("Input meter count must match source channel count."))
        }
        if plan.meterPlan.desktopMeterChannelCount != 2 {
            errors.append(.invalidRenderGraphPlan("Desktop meter count must be stereo."))
        }
        if plan.meterPlan.danteMeterChannelCount != DanteRenderPlan.logicalOutputCount {
            errors.append(.invalidRenderGraphPlan("Dante meter count must be 31 logical channels."))
        }
        return errors
    }

    private func validateLedger(_ plan: RenderGraphPlan) -> [AudioError] {
        var errors: [AudioError] = []
        if !plan.conversionLedger.sessionSampleRate.matches(plan.sessionFormat.sampleRate) {
            errors.append(
                .sampleRateMismatch(
                    expected: plan.sessionFormat.sampleRate,
                    actual: plan.conversionLedger.sessionSampleRate,
                    context: "conversion ledger"
                )
            )
        }
        if plan.conversionLedger.containsProductionSampleRateConversion {
            errors.append(.productionSampleRateConversionForbidden)
        }
        return errors
    }
}

public final class PlanPublicationStore: @unchecked Sendable {
    private let lock = NSLock()
    private let validator: PlanValidator
    private var currentPlan: RenderGraphPlan?

    public init(validator: PlanValidator = PlanValidator()) {
        self.validator = validator
    }

    public func currentPlanSnapshot() -> RenderGraphPlan? {
        lock.lock()
        defer { lock.unlock() }
        return currentPlan
    }

    public func publishValidatedPlan(_ plan: RenderGraphPlan) throws {
        try validator.validateOrThrow(plan)
        lock.lock()
        defer { lock.unlock() }
        if let currentPlan, plan.version <= currentPlan.version {
            throw AudioError.invalidRenderGraphPlan("Plan publication rejected stale version \(plan.version).")
        }
        currentPlan = plan
    }
}

private enum ReferenceStereoDownmixPolicy {
    static let equalPowerCenter = 0.70710678
    static let heightSide = 0.5
    static let topCenter = 0.5 * equalPowerCenter
    static let multichannelHeadroom = 0.50118723

    static func coefficients(
        for role: AudioChannelRole,
        inputIndex: Int,
        sourceChannelCount: Int
    ) -> [Double] {
        let base = baseCoefficients(for: role, inputIndex: inputIndex)
        let headroom = sourceChannelCount > 2 ? multichannelHeadroom : 1.0
        return [base.left * headroom, base.right * headroom]
    }

    private static func baseCoefficients(
        for role: AudioChannelRole,
        inputIndex: Int
    ) -> (left: Double, right: Double) {
        switch role {
        case .frontLeft:
            return (1, 0)
        case .frontRight:
            return (0, 1)
        case .center, .rearCenter:
            return (equalPowerCenter, equalPowerCenter)
        case .lfe, .lfe2:
            return (0, 0)
        case .sideLeft, .rearLeft, .wideLeft, .frontLeftCenter:
            return (equalPowerCenter, 0)
        case .sideRight, .rearRight, .wideRight, .frontRightCenter:
            return (0, equalPowerCenter)
        case .topFrontLeft, .topMiddleLeft, .topRearLeft:
            return (heightSide, 0)
        case .topFrontRight, .topMiddleRight, .topRearRight:
            return (0, heightSide)
        case .topFrontCenter, .topMiddleCenter, .topRearCenter:
            return (topCenter, topCenter)
        case .discrete(let index), .unknown(let index):
            return stereoAlternatingCoefficients(index: index)
        }
    }

    private static func stereoAlternatingCoefficients(index: Int) -> (left: Double, right: Double) {
        let safeIndex = max(index, 0)
        return safeIndex.isMultiple(of: 2) ? (1, 0) : (0, 1)
    }
}

private enum PureAudioDanteMatrixPolicy {
    static func resolvedMode(_ requestedMode: RenderMode, sourceChannelCount: Int) -> RenderMode {
        if requestedMode != .automatic {
            return requestedMode
        }
        switch sourceChannelCount {
        case 1:
            return .mono
        case 2:
            return .stereo
        case 4:
            return .quad
        case 6:
            return .surround51
        case 30:
            return .direct30
        case 31:
            return .direct31
        default:
            return .mono
        }
    }

    static func matrix(
        sourceLayout: AudioChannelLayoutDescriptor,
        renderMode: RenderMode,
        physicalOutputCount: Int
    ) throws -> ImmutableMatrix {
        switch renderMode {
        case .direct30:
            return try directMatrix(
                inputCount: sourceLayout.channelCount,
                physicalOutputCount: physicalOutputCount,
                mapsLFE: false
            )
        case .direct31:
            return try directMatrix(
                inputCount: sourceLayout.channelCount,
                physicalOutputCount: physicalOutputCount,
                mapsLFE: true
            )
        case .mono:
            return try monoMatrix(inputCount: sourceLayout.channelCount, physicalOutputCount: physicalOutputCount)
        default:
            return try deterministicBedMatrix(
                sourceLayout: sourceLayout,
                physicalOutputCount: physicalOutputCount
            )
        }
    }

    private static func directMatrix(
        inputCount: Int,
        physicalOutputCount: Int,
        mapsLFE: Bool
    ) throws -> ImmutableMatrix {
        guard inputCount == (mapsLFE ? 31 : 30) else {
            throw AudioError.invalidRenderGraphPlan("Direct render mode requires \(mapsLFE ? 31 : 30) source channels.")
        }
        var rows = zeroRows(inputCount: inputCount, outputCount: physicalOutputCount)
        for index in 0..<min(30, inputCount, physicalOutputCount) {
            rows[index][index] = 1
        }
        if mapsLFE, inputCount > DanteRenderPlan.lfeOutputIndex, physicalOutputCount > DanteRenderPlan.lfeOutputIndex {
            rows[DanteRenderPlan.lfeOutputIndex][DanteRenderPlan.lfeOutputIndex] = 1
        }
        return try ImmutableMatrix(inputRows: rows)
    }

    private static func monoMatrix(
        inputCount: Int,
        physicalOutputCount: Int
    ) throws -> ImmutableMatrix {
        var rows = zeroRows(inputCount: inputCount, outputCount: physicalOutputCount)
        let outputGain = 1.0 / sqrt(Double(DanteRenderPlan.fullRangeOutputCount))
        let inputTrim = 1.0 / Double(max(inputCount, 1))
        for input in 0..<inputCount {
            for output in 0..<min(DanteRenderPlan.fullRangeOutputCount, physicalOutputCount) {
                rows[input][output] = outputGain * inputTrim
            }
        }
        return try ImmutableMatrix(inputRows: rows)
    }

    private static func deterministicBedMatrix(
        sourceLayout: AudioChannelLayoutDescriptor,
        physicalOutputCount: Int
    ) throws -> ImmutableMatrix {
        var rows = zeroRows(inputCount: sourceLayout.channelCount, outputCount: physicalOutputCount)
        for (input, role) in sourceLayout.roles.enumerated() {
            if role == .lfe || role == .lfe2 {
                if physicalOutputCount > DanteRenderPlan.lfeOutputIndex {
                    rows[input][DanteRenderPlan.lfeOutputIndex] = 1
                }
                continue
            }
            let output = fullRangeOutputIndex(for: role, fallbackInputIndex: input)
            if physicalOutputCount > output {
                rows[input][output] = 1
            }
        }
        return try ImmutableMatrix(inputRows: rows)
    }

    private static func fullRangeOutputIndex(
        for role: AudioChannelRole,
        fallbackInputIndex: Int
    ) -> Int {
        switch role {
        case .frontLeft:
            return 0
        case .frontRight:
            return 1
        case .center:
            return 2
        case .sideLeft, .rearLeft:
            return 3
        case .sideRight, .rearRight:
            return 4
        case .rearCenter:
            return 5
        case .frontLeftCenter, .wideLeft:
            return 6
        case .frontRightCenter, .wideRight:
            return 7
        case .topFrontLeft, .topMiddleLeft, .topRearLeft:
            return 8 + (fallbackInputIndex % 11)
        case .topFrontRight, .topMiddleRight, .topRearRight:
            return 19 + (fallbackInputIndex % 11)
        case .topFrontCenter, .topMiddleCenter, .topRearCenter:
            return 15
        case .lfe, .lfe2:
            return DanteRenderPlan.lfeOutputIndex
        case .discrete(let index), .unknown(let index):
            return max(index, 0) % DanteRenderPlan.fullRangeOutputCount
        }
    }

    private static func zeroRows(inputCount: Int, outputCount: Int) -> [[Double]] {
        Array(
            repeating: Array(repeating: 0.0, count: outputCount),
            count: inputCount
        )
    }
}
