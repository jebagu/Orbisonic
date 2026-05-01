import AudioContracts
import Foundation

public struct AudioBlockFormat: Equatable, Hashable, Sendable {
    public let sampleRate: AudioSampleRate
    public let channelCount: Int
    public let frameCount: Int
    public let processingFormat: ProcessingFormat
    public let layout: AudioChannelLayoutDescriptor

    public init(
        sampleRate: AudioSampleRate,
        channelCount: Int,
        frameCount: Int,
        processingFormat: ProcessingFormat = .float32NonInterleavedPCM,
        layout: AudioChannelLayoutDescriptor
    ) {
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        self.frameCount = frameCount
        self.processingFormat = processingFormat
        self.layout = layout
    }

    public func validationErrors() -> [AudioError] {
        var errors: [AudioError] = []
        if channelCount <= 0 {
            errors.append(.sourceChannelCountOutOfRange(count: channelCount, minimum: 1, maximum: 64))
        }
        if frameCount <= 0 {
            errors.append(.invalidRenderGraphPlan("Audio block frame count must be positive."))
        }
        if !processingFormat.isProductionInternalFormat {
            errors.append(.invalidRenderGraphPlan("Audio blocks must be Float32 non-interleaved PCM."))
        }
        errors.append(contentsOf: layout.validationErrors(expectedChannelCount: channelCount))
        return errors
    }

    public func validate() throws {
        if let error = validationErrors().first {
            throw error
        }
    }
}

public final class CanonicalAudioBlock: @unchecked Sendable {
    public let sampleRate: AudioSampleRate
    public let channelCount: Int
    public let frameCapacity: Int
    public let processingFormat: ProcessingFormat
    public let layout: AudioChannelLayoutDescriptor

    public private(set) var frameCount: Int

    fileprivate var channelStorage: [[Float]]

    public var format: AudioBlockFormat {
        AudioBlockFormat(
            sampleRate: sampleRate,
            channelCount: channelCount,
            frameCount: frameCount,
            processingFormat: processingFormat,
            layout: layout
        )
    }

    public init(format: AudioBlockFormat) throws {
        try format.validate()
        self.sampleRate = format.sampleRate
        self.channelCount = format.channelCount
        self.frameCapacity = format.frameCount
        self.processingFormat = format.processingFormat
        self.layout = format.layout
        self.frameCount = 0
        self.channelStorage = Array(
            repeating: Array(repeating: 0, count: format.frameCount),
            count: format.channelCount
        )
    }

    public func clear() {
        for channel in 0..<channelCount {
            for frame in 0..<frameCapacity {
                channelStorage[channel][frame] = 0
            }
        }
        frameCount = 0
    }

    public func copyFrom(_ source: CanonicalAudioBlock) throws {
        guard source.channelCount == channelCount else {
            throw AudioError.layoutChannelCountMismatch(expected: channelCount, actual: source.channelCount)
        }
        guard source.sampleRate.matches(sampleRate) else {
            throw AudioError.sampleRateMismatch(expected: sampleRate, actual: source.sampleRate, context: "canonical block copy")
        }
        guard source.processingFormat == processingFormat else {
            throw AudioError.invalidRenderGraphPlan("Canonical block processing formats must match.")
        }
        guard source.frameCount <= frameCapacity else {
            throw AudioError.invalidRenderGraphPlan("Destination block capacity is too small.")
        }
        frameCount = source.frameCount
        for channel in 0..<channelCount {
            for frame in 0..<frameCount {
                channelStorage[channel][frame] = source.channelStorage[channel][frame]
            }
            if frameCount < frameCapacity {
                for frame in frameCount..<frameCapacity {
                    channelStorage[channel][frame] = 0
                }
            }
        }
    }

    public func setFrameCount(_ frameCount: Int) throws {
        guard frameCount >= 0, frameCount <= frameCapacity else {
            throw AudioError.invalidRenderGraphPlan("Frame count exceeds block capacity.")
        }
        self.frameCount = frameCount
    }

    public func setSample(_ value: Float, channel: Int, frame: Int) throws {
        guard channel >= 0, channel < channelCount else {
            throw AudioError.layoutChannelCountMismatch(expected: channelCount, actual: channel + 1)
        }
        guard frame >= 0, frame < frameCapacity else {
            throw AudioError.invalidRenderGraphPlan("Frame index exceeds block capacity.")
        }
        channelStorage[channel][frame] = value
        if frame >= frameCount {
            frameCount = frame + 1
        }
    }

    public func setChannelSamples(_ samples: [Float], channel: Int) throws {
        guard channel >= 0, channel < channelCount else {
            throw AudioError.layoutChannelCountMismatch(expected: channelCount, actual: channel + 1)
        }
        guard samples.count <= frameCapacity else {
            throw AudioError.invalidRenderGraphPlan("Channel sample count exceeds block capacity.")
        }
        for frame in 0..<samples.count {
            channelStorage[channel][frame] = samples[frame]
        }
        if samples.count < frameCapacity {
            for frame in samples.count..<frameCapacity {
                channelStorage[channel][frame] = 0
            }
        }
        frameCount = max(frameCount, samples.count)
    }

    public func sample(channel: Int, frame: Int) -> Float {
        guard channel >= 0,
              channel < channelCount,
              frame >= 0,
              frame < frameCount
        else {
            return 0
        }
        return channelStorage[channel][frame]
    }

    public func channelSamplesCopy(channel: Int) -> [Float] {
        guard channel >= 0, channel < channelCount else { return [] }
        return Array(channelStorage[channel].prefix(frameCount))
    }

    fileprivate func prepareForRender(frameCount requestedFrameCount: Int) {
        frameCount = requestedFrameCount
        for channel in 0..<channelCount {
            for frame in 0..<requestedFrameCount {
                channelStorage[channel][frame] = 0
            }
        }
    }
}

public final class CanonicalSourceBus: @unchecked Sendable {
    public let sessionFormat: AudioSessionFormat
    public let source: SourceDescriptor
    public private(set) var frameIndex: Int64

    private let currentBlockStorage: CanonicalAudioBlock

    public init(
        sessionFormat: AudioSessionFormat,
        source: SourceDescriptor,
        frameCapacity: Int
    ) throws {
        try sessionFormat.validate()
        try source.validate(sessionFormat: sessionFormat)
        self.sessionFormat = sessionFormat
        self.source = source
        self.frameIndex = 0
        self.currentBlockStorage = try CanonicalAudioBlock(
            format: AudioBlockFormat(
                sampleRate: sessionFormat.sampleRate,
                channelCount: source.channelCount,
                frameCount: frameCapacity,
                layout: source.layout
            )
        )
    }

    public func injectFixtureBlock(_ block: CanonicalAudioBlock) throws {
        guard block.channelCount == source.channelCount else {
            throw AudioError.layoutChannelCountMismatch(expected: source.channelCount, actual: block.channelCount)
        }
        guard block.sampleRate.matches(sessionFormat.sampleRate) else {
            throw AudioError.sampleRateMismatch(
                expected: sessionFormat.sampleRate,
                actual: block.sampleRate,
                context: "canonical source bus"
            )
        }
        try currentBlockStorage.copyFrom(block)
        frameIndex += Int64(block.frameCount)
    }

    public func copyCurrentBlock(into destination: CanonicalAudioBlock) throws {
        try destination.copyFrom(currentBlockStorage)
    }

    public func currentBlockForTestingCopy() throws -> CanonicalAudioBlock {
        let copy = try CanonicalAudioBlock(
            format: AudioBlockFormat(
                sampleRate: currentBlockStorage.sampleRate,
                channelCount: currentBlockStorage.channelCount,
                frameCount: currentBlockStorage.frameCapacity,
                layout: currentBlockStorage.layout
            )
        )
        try copy.copyFrom(currentBlockStorage)
        return copy
    }
}

public struct MatrixRenderKernel: Sendable {
    public let matrix: ImmutableMatrix

    public init(matrix: ImmutableMatrix) {
        self.matrix = matrix
    }

    public func validate(
        source: CanonicalAudioBlock,
        destination: CanonicalAudioBlock,
        frameCount: Int
    ) throws {
        guard frameCount >= 0 else {
            throw AudioError.invalidRenderGraphPlan("Render frame count must not be negative.")
        }
        guard frameCount <= source.frameCount else {
            throw AudioError.invalidRenderGraphPlan("Render frame count exceeds source frames.")
        }
        guard frameCount <= destination.frameCapacity else {
            throw AudioError.invalidRenderGraphPlan("Render frame count exceeds destination capacity.")
        }
        guard source.processingFormat.isProductionInternalFormat,
              destination.processingFormat.isProductionInternalFormat
        else {
            throw AudioError.invalidRenderGraphPlan("Render kernel requires Float32 non-interleaved PCM blocks.")
        }
        guard source.sampleRate.matches(destination.sampleRate) else {
            throw AudioError.sampleRateMismatch(
                expected: source.sampleRate,
                actual: destination.sampleRate,
                context: "render kernel"
            )
        }
        guard source.channelCount == matrix.inputCount else {
            throw AudioError.layoutChannelCountMismatch(expected: matrix.inputCount, actual: source.channelCount)
        }
        guard destination.channelCount >= matrix.outputCount else {
            throw AudioError.invalidRenderGraphPlan("Destination block has fewer channels than the render matrix.")
        }
    }

    public func process(
        source: CanonicalAudioBlock,
        destination: CanonicalAudioBlock,
        frameCount: Int,
        linearGain: Double = 1.0
    ) throws {
        try validate(source: source, destination: destination, frameCount: frameCount)
        guard linearGain.isFinite, linearGain >= 0 else {
            throw AudioError.invalidRenderGraphPlan("Render gain must be finite and non-negative.")
        }

        destination.prepareForRender(frameCount: frameCount)
        guard frameCount > 0, linearGain > 0 else { return }

        let outputCount = matrix.outputCount
        for input in 0..<matrix.inputCount {
            for output in 0..<outputCount {
                let matrixGain = matrix.gain(input: input, output: output)
                guard abs(matrixGain) > 0.000_001 else { continue }
                let gain = Float(matrixGain * linearGain)
                for frame in 0..<frameCount {
                    destination.channelStorage[output][frame] += source.channelStorage[input][frame] * gain
                }
            }
        }
    }
}

public struct DesktopMonitorRenderer: Sendable {
    public let plan: DesktopDownmixPlan
    public let gainPlan: GainPlan

    private let kernel: MatrixRenderKernel

    public init(plan: DesktopDownmixPlan, gainPlan: GainPlan) {
        self.plan = plan
        self.gainPlan = gainPlan
        self.kernel = MatrixRenderKernel(matrix: plan.coefficients)
    }

    public func process(
        source: CanonicalAudioBlock,
        destination: CanonicalAudioBlock,
        frameCount: Int
    ) throws {
        guard source.sampleRate.matches(plan.sessionSampleRate) else {
            throw AudioError.sampleRateMismatch(
                expected: plan.sessionSampleRate,
                actual: source.sampleRate,
                context: "desktop monitor renderer source"
            )
        }
        guard destination.channelCount == 2 else {
            throw AudioError.desktopRouteInsufficientChannels(required: 2, actual: destination.channelCount)
        }
        guard destination.sampleRate.matches(plan.sessionSampleRate) else {
            throw AudioError.sampleRateMismatch(
                expected: plan.sessionSampleRate,
                actual: destination.sampleRate,
                context: "desktop monitor renderer output"
            )
        }
        try kernel.process(
            source: source,
            destination: destination,
            frameCount: frameCount,
            linearGain: gainPlan.sourceTrim.value * gainPlan.desktopMonitorGain.value
        )
    }
}

public struct DanteSonicSphereRenderer: Sendable {
    public let plan: DanteRenderPlan
    public let gainPlan: GainPlan

    private let kernel: MatrixRenderKernel

    public init(plan: DanteRenderPlan, gainPlan: GainPlan) {
        self.plan = plan
        self.gainPlan = gainPlan
        self.kernel = MatrixRenderKernel(matrix: plan.coefficients)
    }

    public func process(
        source: CanonicalAudioBlock,
        destination: CanonicalAudioBlock,
        frameCount: Int
    ) throws {
        guard source.sampleRate.matches(plan.sessionSampleRate) else {
            throw AudioError.sampleRateMismatch(
                expected: plan.sessionSampleRate,
                actual: source.sampleRate,
                context: "Dante renderer source"
            )
        }
        guard destination.channelCount == plan.physicalOutputCount else {
            throw AudioError.danteRouteInsufficientChannels(
                required: plan.physicalOutputCount,
                actual: destination.channelCount
            )
        }
        guard destination.sampleRate.matches(plan.sessionSampleRate) else {
            throw AudioError.sampleRateMismatch(
                expected: plan.sessionSampleRate,
                actual: destination.sampleRate,
                context: "Dante renderer output"
            )
        }
        try kernel.process(
            source: source,
            destination: destination,
            frameCount: frameCount,
            linearGain: gainPlan.sourceTrim.value * gainPlan.danteOutputGain.value
        )
    }
}

public struct RenderKernelAudit: Equatable, Hashable, Sendable {
    public let sourceSampleRate: AudioSampleRate
    public let desktopOutputSampleRate: AudioSampleRate
    public let danteOutputSampleRate: AudioSampleRate
    public let sourceChannelCount: Int
    public let desktopChannelCount: Int
    public let danteChannelCount: Int
    public let sampleRateConversionOccurred: Bool
    public let allocationMeasurement: String
    public let allocationsDetected: Bool?
    public let renderPlanVersion: UInt64

    public init(
        sourceSampleRate: AudioSampleRate,
        desktopOutputSampleRate: AudioSampleRate,
        danteOutputSampleRate: AudioSampleRate,
        sourceChannelCount: Int,
        desktopChannelCount: Int,
        danteChannelCount: Int,
        sampleRateConversionOccurred: Bool = false,
        allocationMeasurement: String = "not instrumented; process uses preallocated destination blocks",
        allocationsDetected: Bool? = nil,
        renderPlanVersion: UInt64
    ) {
        self.sourceSampleRate = sourceSampleRate
        self.desktopOutputSampleRate = desktopOutputSampleRate
        self.danteOutputSampleRate = danteOutputSampleRate
        self.sourceChannelCount = sourceChannelCount
        self.desktopChannelCount = desktopChannelCount
        self.danteChannelCount = danteChannelCount
        self.sampleRateConversionOccurred = sampleRateConversionOccurred
        self.allocationMeasurement = allocationMeasurement
        self.allocationsDetected = allocationsDetected
        self.renderPlanVersion = renderPlanVersion
    }

    public static func make(
        plan: RenderGraphPlan,
        source: CanonicalAudioBlock,
        desktop: CanonicalAudioBlock,
        dante: CanonicalAudioBlock,
        allocationsDetected: Bool? = nil
    ) -> RenderKernelAudit {
        RenderKernelAudit(
            sourceSampleRate: source.sampleRate,
            desktopOutputSampleRate: desktop.sampleRate,
            danteOutputSampleRate: dante.sampleRate,
            sourceChannelCount: source.channelCount,
            desktopChannelCount: desktop.channelCount,
            danteChannelCount: dante.channelCount,
            sampleRateConversionOccurred: false,
            allocationsDetected: allocationsDetected,
            renderPlanVersion: plan.version
        )
    }
}
