import XCTest
@testable import Orbisonic

final class LiveAudioBridgeTests: XCTestCase {
    func testRingBufferPrimesBeforeReading() {
        let ring = LiveChannelRingBuffer(capacity: 16, targetLatencyFrames: 4, highWaterFrames: 8)
        var output = Array(repeating: Float(-1), count: 2)

        let initialRead = read(from: ring, into: &output)

        XCTAssertEqual(initialRead, 0)
        XCTAssertEqual(output, [0, 0])

        write([1, 2, 3], to: ring)
        let underTargetRead = read(from: ring, into: &output)

        XCTAssertEqual(underTargetRead, 0)
        XCTAssertEqual(output, [0, 0])

        write([4], to: ring)
        let primedRead = read(from: ring, into: &output)

        XCTAssertEqual(primedRead, 2)
        XCTAssertEqual(output, [1, 2])
        XCTAssertFalse(ring.status().isPriming)
    }

    func testRingBufferReprimesAfterUnderflow() {
        let ring = LiveChannelRingBuffer(capacity: 16, targetLatencyFrames: 4, highWaterFrames: 8)
        var output = Array(repeating: Float(-1), count: 6)

        write([1, 2, 3, 4], to: ring)
        let underflowRead = read(from: ring, into: &output)

        XCTAssertEqual(underflowRead, 4)
        XCTAssertEqual(output, [1, 2, 3, 4, 0, 0])
        XCTAssertTrue(ring.status().isPriming)
        XCTAssertEqual(ring.status().underflowCount, 1)

        var secondOutput = Array(repeating: Float(-1), count: 2)
        write([10, 11, 12], to: ring)
        let stillPrimingRead = read(from: ring, into: &secondOutput)

        XCTAssertEqual(stillPrimingRead, 0)
        XCTAssertEqual(secondOutput, [0, 0])

        write([13], to: ring)
        let recoveredRead = read(from: ring, into: &secondOutput)

        XCTAssertEqual(recoveredRead, 2)
        XCTAssertEqual(secondOutput, [10, 11])
    }

    func testRingBufferDropsExcessFramesInsteadOfGrowingLatency() {
        let ring = LiveChannelRingBuffer(capacity: 16, targetLatencyFrames: 4, highWaterFrames: 8)
        var output = Array(repeating: Float(-1), count: 4)

        write(Array(0..<10).map(Float.init), to: ring)
        let status = ring.status()

        XCTAssertEqual(status.availableFrames, 4)
        XCTAssertEqual(status.overflowDropFrames, 6)

        let read = read(from: ring, into: &output)

        XCTAssertEqual(read, 4)
        XCTAssertEqual(output, [6, 7, 8, 9])
    }

    private func write(_ values: [Float], to ring: LiveChannelRingBuffer) {
        values.withUnsafeBufferPointer { sourcePointer in
            ring.write(sourcePointer.baseAddress!, frameCount: values.count)
        }
    }

    private func read(from ring: LiveChannelRingBuffer, into output: inout [Float]) -> Int {
        let frameCount = output.count
        return output.withUnsafeMutableBufferPointer { outputPointer in
            ring.read(into: outputPointer.baseAddress!, frameCount: frameCount)
        }
    }
}
