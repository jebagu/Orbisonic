import Darwin
import Foundation

final class RealtimeAtomicInt {
    private var value: Int64

    init(_ value: Int = 0) {
        self.value = Int64(value)
    }

    func load() -> Int {
        Int(OSAtomicAdd64Barrier(0, &value))
    }

    func store(_ nextValue: Int) {
        OSMemoryBarrier()
        value = Int64(nextValue)
        OSMemoryBarrier()
    }

    func add(_ delta: Int) {
        OSAtomicAdd64Barrier(Int64(delta), &value)
    }

    func max(_ candidate: Int) {
        var current = load()
        while candidate > current {
            if OSAtomicCompareAndSwap64Barrier(Int64(current), Int64(candidate), &value) {
                return
            }
            current = load()
        }
    }
}

final class RealtimeAtomicFlag {
    private var value: Int32

    init(initialValue: Bool = false) {
        value = initialValue ? 1 : 0
    }

    func load() -> Bool {
        OSAtomicAdd32Barrier(0, &value) != 0
    }

    func store(_ nextValue: Bool) {
        OSMemoryBarrier()
        value = nextValue ? 1 : 0
        OSMemoryBarrier()
    }

    func tryEnter() -> Bool {
        OSAtomicCompareAndSwap32Barrier(0, 1, &value)
    }
}

final class RealtimeAtomicFloat {
    private var bitPattern: Int32

    init(_ value: Float = 0) {
        bitPattern = Int32(bitPattern: value.bitPattern)
    }

    func store(_ value: Float) {
        OSMemoryBarrier()
        bitPattern = Int32(bitPattern: value.bitPattern)
        OSMemoryBarrier()
    }

    func load() -> Float {
        Float(bitPattern: UInt32(bitPattern: OSAtomicAdd32Barrier(0, &bitPattern)))
    }
}

final class RealtimeMeterLevelStorage {
    private let levels: [RealtimeAtomicFloat]

    init(channelCount: Int) {
        levels = (0..<max(channelCount, 0)).map { _ in RealtimeAtomicFloat() }
    }

    func store(channel: Int, level: Float) {
        guard channel >= 0, channel < levels.count else { return }
        levels[channel].store(level)
    }

    func clear() {
        for level in levels {
            level.store(0)
        }
    }

    func snapshot() -> [Float] {
        levels.map { $0.load() }
    }
}
