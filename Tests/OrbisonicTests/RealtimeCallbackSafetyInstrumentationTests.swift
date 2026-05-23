import AVFoundation
import XCTest
@testable import Orbisonic

final class RealtimeCallbackSafetyInstrumentationTests: XCTestCase {
    func testStandardStressHarnessReportsRequiredMetricsAndWarnings() {
        let report = RealtimeCallbackStressHarness.standardSyntheticReport()

        XCTAssertEqual(report.scene, .orbisonicMaximumConfigured)
        XCTAssertEqual(report.scene.inputChannelCount, OrbisonicAudioLimits.maxSourceChannelCount)
        XCTAssertEqual(report.scene.outputChannelCount, 31)
        XCTAssertTrue(report.scene.uiActive)
        XCTAssertTrue(report.scene.metersActive)
        XCTAssertTrue(report.scene.telemetryActive)
        XCTAssertTrue(report.scene.routeValidationBeforeArming)
        XCTAssertEqual(report.timing.callbackCount, 512)
        XCTAssertEqual(report.counters.maxEventsDrainedPerBlock, 16)
        XCTAssertEqual(report.counters.eventDropOrCoalesceCount, 2)
        XCTAssertEqual(report.counters.telemetryDropCount, 1)
        XCTAssertEqual(report.counters.meterDropOrCoalesceCount, 3)
        XCTAssertEqual(report.counters.routeMismatchBlockCount, 1)
        XCTAssertEqual(report.gateStatus, .warning)
        XCTAssertTrue(report.warnings.contains("denormal handling is not verified"))

        for label in [
            "sample rate",
            "block size range",
            "callback duration p50",
            "callback duration p95",
            "callback duration p99",
            "callback allocation count",
            "callback blocking-lock count",
            "telemetry drops",
            "denormal handling status",
            "route mismatch behavior"
        ] {
            XCTAssertTrue(report.requiredMetricLabels.contains(label), "Missing required metric label: \(label)")
        }

        XCTAssertTrue(report.textSummary.contains("Gate status: warning"))
        XCTAssertTrue(report.textSummary.contains("Route mismatch behavior: blocked before arming"))
    }

    func testBudgetGateBlocksDeadlineMissAndP99Violation() {
        let probe = RealtimeCallbackSafetyProbe(sampleRate: 48_000, sampleCapacity: 8)
        probe.recordCallbackDuration(nanoseconds: 10_000_000, blockSize: 128)

        let report = probe.report(
            denormalHandlingStatus: .flushToZeroVerified,
            routeMismatchBehavior: .blockedBeforeArming
        )

        XCTAssertEqual(report.gateStatus, .blocked)
        XCTAssertEqual(report.timing.deadlineMissCount, 1)
        XCTAssertTrue(report.blockingReasons.contains("deadline misses are nonzero"))
        XCTAssertTrue(report.blockingReasons.contains("p99 callback duration exceeds budget"))
    }

    func testLiveMatrixRenderRecordsCurrentAllocationGap() throws {
        let probe = RealtimeCallbackSafetyProbe(sampleRate: 48_000, sampleCapacity: 16)
        let service = MeteringService()
        let pipe = LiveAudioPipe(
            channelCount: 2,
            sampleRate: 48_000,
            latencySeconds: 0.01,
            meteringService: service,
            callbackSafetyProbe: probe
        )
        let input = try Self.makeBuffer(channelCount: 2, frameCount: 512) { channel, frame in
            channel == 0 ? Float(frame) / 512 : -Float(frame) / 512
        }
        pipe.write(buffer: input)

        let output = try XCTUnwrap(AVAudioPCMBuffer(
            pcmFormat: try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2)),
            frameCapacity: 128
        ))
        output.frameLength = 128

        let status = pipe.render(
            matrix: RendererMatrix(gains: [[1, 0], [0, 1]]),
            audioBufferList: output.mutableAudioBufferList,
            frameCount: 128
        )
        XCTAssertEqual(status, noErr)

        let report = probe.report(
            denormalHandlingStatus: .flushToZeroVerified,
            routeMismatchBehavior: .blockedBeforeArming
        )
        XCTAssertEqual(report.counters.callbackAllocationCount, 3)
        XCTAssertEqual(report.gateStatus, .blocked)
        XCTAssertTrue(report.blockingReasons.contains("callback allocations are nonzero"))
    }

    func testRouteMismatchRecordsBlockedBehaviorWithoutThrowingFromCallback() throws {
        let probe = RealtimeCallbackSafetyProbe(sampleRate: 48_000, sampleCapacity: 16)
        let pipe = LiveAudioPipe(
            channelCount: 2,
            sampleRate: 48_000,
            latencySeconds: 0.01,
            callbackSafetyProbe: probe
        )
        let output = try XCTUnwrap(AVAudioPCMBuffer(
            pcmFormat: try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2)),
            frameCapacity: 64
        ))
        output.frameLength = 64

        let status = pipe.render(
            matrix: RendererMatrix(gains: [[1, 0]]),
            audioBufferList: output.mutableAudioBufferList,
            frameCount: 64
        )
        XCTAssertEqual(status, noErr)

        let report = probe.report(
            denormalHandlingStatus: .flushToZeroVerified,
            routeMismatchBehavior: .blockedBeforeArming
        )
        XCTAssertEqual(report.counters.routeMismatchBlockCount, 1)
        XCTAssertEqual(report.counters.callbackAllocationCount, 0)
        XCTAssertEqual(report.gateStatus, .passed)
    }

    private static func makeBuffer(
        channelCount: Int,
        frameCount: Int,
        sample: (Int, Int) -> Float
    ) throws -> AVAudioPCMBuffer {
        let format = try XCTUnwrap(AVAudioFormat(
            standardFormatWithSampleRate: 48_000,
            channels: AVAudioChannelCount(channelCount)
        ))
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(frameCount)
        ))
        buffer.frameLength = AVAudioFrameCount(frameCount)
        let channelData = try XCTUnwrap(buffer.floatChannelData)
        for channel in 0..<channelCount {
            for frame in 0..<frameCount {
                channelData[channel][frame] = sample(channel, frame)
            }
        }
        return buffer
    }
}
