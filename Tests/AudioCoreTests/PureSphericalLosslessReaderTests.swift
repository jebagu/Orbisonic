import AudioContracts
import AudioCore
import XCTest

final class PureSphericalLosslessReaderTests: XCTestCase {
    private let tolerance: Float = 0.000_001

    func testReadsFloat32BW64RenderMasterAsRenderedSphereBlock() throws {
        let url = try writeBW64(
            name: "float-render-master.bw64",
            manifest: manifest(sampleFormat: "float32"),
            encoding: .float32,
            frames: [[0.01, 0.02, 0.03], [0.11, 0.12, 0.13]]
        )
        let validation = try validated(url)
        let reader = PureSphericalLosslessReader()

        try reader.open(validation: validation, context: context(sourceID: "float-master"))
        let result = try reader.readBlock(maxFrames: 2)

        XCTAssertEqual(result.renderedBlock.sourceID, "float-master")
        XCTAssertEqual(result.renderedBlock.channelCount, 31)
        XCTAssertEqual(result.renderedBlock.contract.frameCount, 2)
        XCTAssertEqual(result.renderedBlock.outputMapID, "direct-30.1-logical")
        XCTAssertEqual(result.renderedBlock.sphereProfileID, "sonic-sphere-31-reference")
        XCTAssertEqual(result.renderedBlock.contract.layout.authority, .pureSphericalManifest)
        XCTAssertEqual(result.samples.channelCount, 31)
        XCTAssertEqual(result.samples.frameCount, 2)
        XCTAssertEqual(result.samples.sample(channel: 0, frame: 0), 0.01, accuracy: tolerance)
        XCTAssertEqual(result.samples.sample(channel: 0, frame: 1), 0.02, accuracy: tolerance)
        XCTAssertEqual(result.samples.sample(channel: 1, frame: 0), 0.11, accuracy: tolerance)
        XCTAssertEqual(result.samples.sample(channel: 30, frame: 0), 0, accuracy: tolerance)
        XCTAssertTrue(result.ledger.contains(stage: .directRead, owner: .pureSphericalLosslessReader))
        XCTAssertFalse(result.ledger.hasHiddenConversionRisk)
    }

    func testReadsTwentyFourBitBW64DantePrintWithCorrectWidening() throws {
        let url = try writeBW64(
            name: "dante-print.bw64",
            manifest: manifest(sampleFormat: "pcm24"),
            encoding: .pcm24Integer,
            frames: [[4_194_304, -2_097_152], [1_048_576, -1_048_576]]
        )
        let validation = try validated(url)
        let reader = PureSphericalLosslessReader()

        try reader.open(validation: validation, context: context(sourceID: "pcm24-print"))
        let result = try reader.readBlock(maxFrames: 2)

        XCTAssertEqual(result.sourceFormat.encoding, .pcm24Integer)
        XCTAssertEqual(result.sourceFormat.bitsPerSample, 24)
        XCTAssertEqual(result.samples.sample(channel: 0, frame: 0), 0.5, accuracy: tolerance)
        XCTAssertEqual(result.samples.sample(channel: 0, frame: 1), -0.25, accuracy: tolerance)
        XCTAssertEqual(result.samples.sample(channel: 1, frame: 0), 0.125, accuracy: tolerance)
        XCTAssertEqual(result.samples.sample(channel: 1, frame: 1), -0.125, accuracy: tolerance)
    }

    func testReadsCAFRenderMasterWithoutChangingChannelOrder() throws {
        let url = try writeCAF(
            name: "caf-render-master.caf",
            manifest: manifest(sampleFormat: "float32"),
            frames: [[0.03, 0.04], [0.13, 0.14], [0.23, 0.24]]
        )
        let validation = try validated(url)
        let reader = PureSphericalLosslessReader()

        try reader.open(validation: validation, context: context(sourceID: "caf-master"))
        let result = try reader.readBlock(maxFrames: 2)

        XCTAssertEqual(result.sourceFormat.containerKind, .caf)
        XCTAssertEqual(result.sourceFormat.encoding, .float32)
        XCTAssertEqual(result.samples.sample(channel: 0, frame: 0), 0.03, accuracy: tolerance)
        XCTAssertEqual(result.samples.sample(channel: 1, frame: 0), 0.13, accuracy: tolerance)
        XCTAssertEqual(result.samples.sample(channel: 2, frame: 0), 0.23, accuracy: tolerance)
        XCTAssertEqual(result.samples.sample(channel: 0, frame: 1), 0.04, accuracy: tolerance)
        XCTAssertEqual(result.samples.sample(channel: 1, frame: 1), 0.14, accuracy: tolerance)
        XCTAssertEqual(result.samples.sample(channel: 2, frame: 1), 0.24, accuracy: tolerance)
    }

    func testReservedChannelMustRemainSilent() throws {
        let reservedIndex = 30
        let url = try writeBW64(
            name: "reserved-not-silent.bw64",
            manifest: manifest(sampleFormat: "float32", reservedSilentIndexes: [reservedIndex]),
            encoding: .float32,
            frames: [[0.01], [0.02]],
            channelOverrides: [reservedIndex: [0.25]]
        )
        let validation = try validated(url)
        let reader = PureSphericalLosslessReader()
        try reader.open(validation: validation)

        XCTAssertThrowsError(try reader.readBlock(maxFrames: 1)) { error in
            guard case AudioError.invalidRenderGraphPlan(let message) = error else {
                return XCTFail("Expected reserved channel silence error, got \(error).")
            }
            XCTAssertTrue(message.contains("reserved channel 30"))
            XCTAssertTrue(message.contains("not silent"))
        }
    }

    func testReaderRefusesNonCurrentSphereValidationBeforeReading() throws {
        let url = try writeBW64(
            name: "different-sphere.bw64",
            manifest: manifest(sampleFormat: "float32", sphereProfileID: "different-sphere"),
            encoding: .float32,
            frames: [[0.01]]
        )
        let validation = try PureSphericalLosslessValidator().validate(
            url: url,
            currentSphere: .directThirtyOne(),
            route: route(channels: 32)
        )

        XCTAssertEqual(validation.state, .validForDifferentSphere)
        XCTAssertThrowsError(try PureSphericalLosslessReader().open(validation: validation)) { error in
            XCTAssertEqual(
                error as? AudioError,
                .invalidRenderGraphPlan(
                    "PureSphericalLosslessReader requires a file validated for the current sphere."
                )
            )
        }
    }

    func testReaderLedgerAndSourceDoNotUseForbiddenPlaybackOwners() throws {
        let url = try writeBW64(
            name: "direct-playback.bw64",
            manifest: manifest(sampleFormat: "float32"),
            encoding: .float32,
            frames: [[0.01]]
        )
        let validation = try validated(url)
        let reader = PureSphericalLosslessReader()

        try reader.open(validation: validation)
        let result = try reader.readBlock(maxFrames: 1)

        XCTAssertFalse(result.ledger.contains(stage: .downmix, owner: .vlc))
        XCTAssertFalse(result.ledger.contains(stage: .render, owner: .sonicSphereRenderer))
        XCTAssertFalse(result.ledger.entries.contains { $0.owner == .vlc })
        XCTAssertFalse(result.ledger.entries.contains { $0.owner == .sonicSphereRenderer })

        let source = try String(contentsOf: readerSourceURL(), encoding: .utf8)
        for forbidden in [
            "OrbisonicVLCReference",
            "CLibVLCBridge",
            "VlcLocalStereoMonitorSource",
            "SonicSphereRenderer",
            "MatrixSonicSphereRenderer"
        ] {
            XCTAssertFalse(source.contains(forbidden), "PureSphericalLosslessReader.swift references \(forbidden)")
        }
    }

    private enum FixtureEncoding {
        case float32
        case pcm24Integer
    }

    private func validated(_ url: URL) throws -> PureSphericalLosslessValidation {
        try PureSphericalLosslessValidator().validate(
            url: url,
            currentSphere: .directThirtyOne(),
            route: route(channels: 32)
        )
    }

    private func context(sourceID: String) -> PureSphericalLosslessReaderContext {
        PureSphericalLosslessReaderContext(
            sessionID: "pure-spherical-reader-tests",
            sourceID: sourceID,
            sourceKind: .localFile,
            generation: 42
        )
    }

    private func manifest(
        sampleFormat: String,
        sphereProfileID: String = "sonic-sphere-31-reference",
        reservedSilentIndexes: Set<Int> = []
    ) -> PureSphericalLosslessManifest {
        let channelCount = 31
        return PureSphericalLosslessManifest(
            sampleRate: .rate48000,
            channelCount: channelCount,
            sampleFormat: sampleFormat,
            sphereProfileID: sphereProfileID,
            calibrationID: "test-calibration",
            outputMapID: "direct-30.1-logical",
            rendererVersion: "orbisonic-renderer-v2-test",
            rendererMatrixHash: "sha256:test",
            channels: (0..<channelCount).map { index in
                PureSphericalLosslessChannelManifest(
                    index: index,
                    channelID: "ch-\(index + 1)",
                    speakerID: index == 30 ? "lfe" : "speaker-\(index + 1)",
                    logicalOutputChannel: index + 1,
                    physicalOutputChannel: index + 1,
                    danteTransmitChannel: index + 1,
                    role: index == 30 ? "lfe" : "speaker",
                    isReservedSilent: reservedSilentIndexes.contains(index)
                )
            }
        )
    }

    private func route(
        channels: Int,
        sampleRate: AudioSampleRate = .rate48000
    ) -> OutputRouteDescriptor {
        OutputRouteDescriptor(
            id: "dante",
            uid: "dante",
            name: "Dante Virtual Soundcard",
            manufacturer: "Audinate",
            transportName: "Dante",
            outputChannelCount: channels,
            nominalSampleRate: sampleRate,
            isAvailable: true,
            risk: .preferredDante
        )
    }

    private func writeBW64(
        name: String,
        manifest: PureSphericalLosslessManifest,
        encoding: FixtureEncoding,
        frames: [[Any]],
        channelOverrides: [Int: [Any]] = [:]
    ) throws -> URL {
        let url = try fixtureURL(name: name)
        let channelCount = manifest.channelCount
        let frameCount = frames.first?.count ?? 0
        var payload = Data()

        for frame in 0..<frameCount {
            for channel in 0..<channelCount {
                let source = channelOverrides[channel]
                    ?? (channel < frames.count ? frames[channel] : Array(repeating: 0, count: frameCount))
                switch encoding {
                case .float32:
                    payload.appendFloat32LE(Float(truncating: source[frame] as! NSNumber))
                case .pcm24Integer:
                    payload.appendInt24LE(Int32(truncating: source[frame] as! NSNumber))
                }
            }
        }

        var data = Data()
        data.appendASCII("BW64")
        data.appendUInt32LE(UInt32(4 + 8 + 16 + 8 + payload.count))
        data.appendASCII("WAVE")
        data.appendASCII("fmt ")
        data.appendUInt32LE(16)
        switch encoding {
        case .float32:
            data.appendUInt16LE(3)
            data.appendUInt16LE(UInt16(channelCount))
            data.appendUInt32LE(48_000)
            data.appendUInt32LE(UInt32(48_000 * channelCount * 4))
            data.appendUInt16LE(UInt16(channelCount * 4))
            data.appendUInt16LE(32)
        case .pcm24Integer:
            data.appendUInt16LE(1)
            data.appendUInt16LE(UInt16(channelCount))
            data.appendUInt32LE(48_000)
            data.appendUInt32LE(UInt32(48_000 * channelCount * 3))
            data.appendUInt16LE(UInt16(channelCount * 3))
            data.appendUInt16LE(24)
        }
        data.appendASCII("data")
        data.appendUInt32LE(UInt32(payload.count))
        data.append(payload)
        try data.write(to: url)
        try writeSidecar(for: url, manifest: manifest)
        return url
    }

    private func writeCAF(
        name: String,
        manifest: PureSphericalLosslessManifest,
        frames: [[Float]]
    ) throws -> URL {
        let url = try fixtureURL(name: name)
        let channelCount = manifest.channelCount
        let frameCount = frames.first?.count ?? 0
        var payload = Data()
        for frame in 0..<frameCount {
            for channel in 0..<channelCount {
                let source = channel < frames.count ? frames[channel] : Array(repeating: Float(0), count: frameCount)
                payload.appendFloat32LE(source[frame])
            }
        }

        var desc = Data()
        desc.appendDouble64BE(48_000)
        desc.appendASCII("lpcm")
        desc.appendUInt32BE(0x1 | 0x8)
        desc.appendUInt32BE(UInt32(channelCount * 4))
        desc.appendUInt32BE(1)
        desc.appendUInt32BE(UInt32(channelCount))
        desc.appendUInt32BE(32)

        var data = Data()
        data.appendASCII("caff")
        data.appendUInt16BE(1)
        data.appendUInt16BE(0)
        data.appendASCII("desc")
        data.appendUInt64BE(UInt64(desc.count))
        data.append(desc)
        data.appendASCII("data")
        data.appendUInt64BE(UInt64(payload.count + 4))
        data.appendUInt32BE(0)
        data.append(payload)
        try data.write(to: url)
        try writeSidecar(for: url, manifest: manifest)
        return url
    }

    private func writeSidecar(
        for url: URL,
        manifest: PureSphericalLosslessManifest
    ) throws {
        try JSONEncoder().encode(manifest).write(to: url.appendingPathExtension("orbi.json"))
    }

    private func fixtureURL(name: String) throws -> URL {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("PureSphericalLosslessReaderTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent(name)
    }

    private func readerSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/AudioCore/PureSphericalLosslessReader.swift")
    }
}

private extension Data {
    mutating func appendASCII(_ value: String) {
        append(Data(value.utf8))
    }

    mutating func appendUInt16LE(_ value: UInt16) {
        append(UInt8(value & 0xff))
        append(UInt8((value >> 8) & 0xff))
    }

    mutating func appendUInt16BE(_ value: UInt16) {
        append(UInt8((value >> 8) & 0xff))
        append(UInt8(value & 0xff))
    }

    mutating func appendUInt32LE(_ value: UInt32) {
        append(UInt8(value & 0xff))
        append(UInt8((value >> 8) & 0xff))
        append(UInt8((value >> 16) & 0xff))
        append(UInt8((value >> 24) & 0xff))
    }

    mutating func appendUInt32BE(_ value: UInt32) {
        append(UInt8((value >> 24) & 0xff))
        append(UInt8((value >> 16) & 0xff))
        append(UInt8((value >> 8) & 0xff))
        append(UInt8(value & 0xff))
    }

    mutating func appendUInt64BE(_ value: UInt64) {
        for shift in stride(from: 56, through: 0, by: -8) {
            append(UInt8((value >> UInt64(shift)) & 0xff))
        }
    }

    mutating func appendFloat32LE(_ value: Float) {
        appendUInt32LE(value.bitPattern)
    }

    mutating func appendDouble64BE(_ value: Double) {
        appendUInt64BE(value.bitPattern)
    }

    mutating func appendInt24LE(_ value: Int32) {
        let clamped = Swift.max(-8_388_608, Swift.min(8_388_607, value))
        let raw = UInt32(bitPattern: clamped) & 0x00ff_ffff
        append(UInt8(raw & 0xff))
        append(UInt8((raw >> 8) & 0xff))
        append(UInt8((raw >> 16) & 0xff))
    }
}
