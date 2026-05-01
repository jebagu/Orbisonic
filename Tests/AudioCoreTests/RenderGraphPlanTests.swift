import AudioContracts
import AudioCore
import XCTest

final class RenderGraphPlanTests: XCTestCase {
    func testRenderGraphPlanIsImmutableFromPublicAPI() throws {
        let matrix = try ImmutableMatrix(inputRows: [
            [1, 0],
            [0, 1]
        ])
        var copy = matrix.gainsCopy()
        copy[0][0] = 0

        XCTAssertEqual(matrix.gain(input: 0, output: 0), 1)
        XCTAssertEqual(matrix.gain(input: 1, output: 1), 1)

        let source = try String(contentsOf: renderGraphPlanSourceURL(), encoding: .utf8)
        XCTAssertFalse(source.contains("public let inputMajorGains"))
        XCTAssertFalse(source.contains("public var inputMajorGains"))
    }

    func testPlanValidatorAcceptsValidStereoSourceToDesktopAndDantePlan() throws {
        let plan = try validPlan(source: stereoSource())
        let errors = PlanValidator().validate(plan)

        XCTAssertTrue(errors.isEmpty, errors.map(\.description).joined(separator: "\n"))
        XCTAssertEqual(plan.desktopDownmix.coefficients.outputCount, 2)
        XCTAssertEqual(plan.danteRenderer.coefficients.outputCount, 32)
        XCTAssertTrue(plan.danteRenderer.isPhysicalChannel32Silent)
    }

    func testPlanValidatorRejectsSourceSampleRateMismatch() throws {
        let source = SourceDescriptor(
            id: "stereo-44",
            kind: .localFile,
            sampleRate: .rate44100,
            channelCount: 2,
            layout: .stereo
        )
        let plan = try planCopy(validPlan(source: stereoSource()), source: source)

        XCTAssertTrue(
            PlanValidator().validate(plan).contains {
                if case .sampleRateMismatch(_, _, let context) = $0 {
                    return context == "source"
                }
                return false
            }
        )
    }

    func testPlanValidatorRejectsDesktopMatrixNotTwoChannels() throws {
        let base = try validPlan(source: stereoSource())
        let desktop = DesktopDownmixPlan(
            outputChannelCount: 1,
            sessionSampleRate: base.sessionFormat.sampleRate,
            sourceLayout: base.source.layout,
            coefficients: try ImmutableMatrix(inputRows: [
                [1],
                [1]
            ]),
            headroomGain: .unity
        )
        let plan = planCopy(base, desktopDownmix: desktop)

        XCTAssertTrue(
            PlanValidator().validate(plan).contains(.desktopRouteInsufficientChannels(required: 2, actual: 1))
        )
    }

    func testPlanValidatorRejectsDanteMatrixBelowThirtyOneOutputs() throws {
        let base = try validPlan(source: stereoSource())
        let dante = DanteRenderPlan(
            physicalOutputCount: 30,
            sessionSampleRate: base.sessionFormat.sampleRate,
            sourceLayout: base.source.layout,
            renderMode: .stereo,
            coefficients: try ImmutableMatrix(inputRows: [
                Array(repeating: 0.0, count: 30),
                Array(repeating: 0.0, count: 30)
            ])
        )
        let plan = planCopy(base, danteRenderer: dante)

        XCTAssertTrue(
            PlanValidator().validate(plan).contains(.danteRouteInsufficientChannels(required: 31, actual: 30))
        )
    }

    func testPlanValidatorRejectsPhysicalThirtyTwoPlanIfChannelThirtyTwoIsNotSilentOrReserved() throws {
        let base = try validPlan(source: stereoSource())
        var rows = Array(repeating: Array(repeating: 0.0, count: 32), count: 2)
        rows[0][DanteRenderPlan.reservedPhysicalOutputIndex] = 1
        let dante = DanteRenderPlan(
            physicalOutputCount: 32,
            channel32Reserved: false,
            sessionSampleRate: base.sessionFormat.sampleRate,
            sourceLayout: base.source.layout,
            renderMode: .stereo,
            coefficients: try ImmutableMatrix(inputRows: rows)
        )
        let plan = planCopy(base, danteRenderer: dante)
        let errors = PlanValidator().validate(plan).map(\.description).joined(separator: "\n")

        XCTAssertTrue(errors.contains("Dante physical channel 32 must be reserved."), errors)
        XCTAssertTrue(errors.contains("Dante physical channel 32 must be silent."), errors)
    }

    func testDirect30MapsFirstThirtySourceChannelsToFirstThirtyFullRangeOutputs() throws {
        let source = SourceDescriptor(
            id: "direct30",
            kind: .localFile,
            sampleRate: .rate48000,
            channelCount: 30,
            layout: .direct30
        )
        let plan = try validPlan(source: source, renderMode: .direct30)

        for index in 0..<30 {
            XCTAssertEqual(plan.danteRenderer.coefficients.gain(input: index, output: index), 1)
        }
        XCTAssertEqual(plan.danteRenderer.coefficients.gain(input: 29, output: 30), 0)
        XCTAssertTrue(plan.danteRenderer.isPhysicalChannel32Silent)
    }

    func testDirect31MapsChannelThirtyOneToLFESub() throws {
        let source = SourceDescriptor(
            id: "direct31",
            kind: .localFile,
            sampleRate: .rate48000,
            channelCount: 31,
            layout: .direct31
        )
        let plan = try validPlan(source: source, renderMode: .direct31)

        for index in 0..<30 {
            XCTAssertEqual(plan.danteRenderer.coefficients.gain(input: index, output: index), 1)
        }
        XCTAssertEqual(
            plan.danteRenderer.coefficients.gain(
                input: DanteRenderPlan.lfeOutputIndex,
                output: DanteRenderPlan.lfeOutputIndex
            ),
            1
        )
        XCTAssertTrue(plan.danteRenderer.isPhysicalChannel32Silent)
    }

    func testReferenceStereoDownmixOmitsLFEByDefault() throws {
        let source = SourceDescriptor(
            id: "five-one",
            kind: .localFile,
            sampleRate: .rate48000,
            channelCount: 6,
            layout: .surround51
        )
        let plan = try validPlan(source: source, renderMode: .surround51)

        XCTAssertEqual(plan.desktopDownmix.coefficients.gain(input: 3, output: 0), 0)
        XCTAssertEqual(plan.desktopDownmix.coefficients.gain(input: 3, output: 1), 0)
    }

    func testDesktopGainDoesNotChangeDanteMatrixOrDanteGain() throws {
        let source = stereoSource()
        let base = try validPlan(source: source)
        let withDesktopGain = try validPlan(
            source: source,
            gainPlan: GainPlan(
                sourceTrim: .unity,
                desktopMonitorGain: try LinearGain(0.25),
                danteOutputGain: .unity,
                meterCalibrationGain: .unity,
                testToneCalibrationGain: .unity
            )
        )

        XCTAssertEqual(base.danteRenderer.coefficients, withDesktopGain.danteRenderer.coefficients)
        XCTAssertEqual(base.gainPlan.danteOutputGain, withDesktopGain.gainPlan.danteOutputGain)
        XCTAssertNotEqual(base.gainPlan.desktopMonitorGain, withDesktopGain.gainPlan.desktopMonitorGain)
    }

    func testMeterCalibrationDoesNotChangeAudibleGain() throws {
        let base = try validPlan(source: stereoSource())
        let calibratedMeters = try validPlan(
            source: stereoSource(),
            gainPlan: GainPlan(
                sourceTrim: .unity,
                desktopMonitorGain: .unity,
                danteOutputGain: .unity,
                meterCalibrationGain: try LinearGain(0.5),
                testToneCalibrationGain: .unity
            )
        )

        XCTAssertEqual(base.gainPlan.audibleGains, calibratedMeters.gainPlan.audibleGains)
        XCTAssertNotEqual(base.gainPlan.meterCalibrationGain, calibratedMeters.gainPlan.meterCalibrationGain)
        XCTAssertEqual(base.desktopDownmix.coefficients, calibratedMeters.desktopDownmix.coefficients)
        XCTAssertEqual(base.danteRenderer.coefficients, calibratedMeters.danteRenderer.coefficients)
    }

    func testPublishInvalidPlanFails() throws {
        let store = PlanPublicationStore()
        let base = try validPlan(source: stereoSource())
        let invalidDesktop = DesktopDownmixPlan(
            outputChannelCount: 2,
            sessionSampleRate: base.sessionFormat.sampleRate,
            sourceLayout: base.source.layout,
            coefficients: try ImmutableMatrix(inputRows: [[1], [1]]),
            headroomGain: .unity
        )
        let invalidPlan = planCopy(base, desktopDownmix: invalidDesktop)

        XCTAssertThrowsError(try store.publishValidatedPlan(invalidPlan))
        XCTAssertNil(store.currentPlanSnapshot())
    }

    func testPublishValidPlanSucceedsAndExposesReadOnlySnapshot() throws {
        let store = PlanPublicationStore()
        let first = try validPlan(source: stereoSource(), version: 1)
        try store.publishValidatedPlan(first)

        var snapshotCopy = try XCTUnwrap(store.currentPlanSnapshot())
        XCTAssertEqual(snapshotCopy.version, 1)
        snapshotCopy = planCopy(snapshotCopy, validationMessages: ["mutated local copy"])

        let storedAgain = try XCTUnwrap(store.currentPlanSnapshot())
        XCTAssertEqual(storedAgain.validationMessages, [])
        XCTAssertThrowsError(try store.publishValidatedPlan(first))

        let second = try validPlan(source: stereoSource(), version: 2)
        try store.publishValidatedPlan(second)
        XCTAssertEqual(store.currentPlanSnapshot()?.version, 2)
    }

    private func validPlan(
        source: SourceDescriptor,
        sessionFormat: AudioSessionFormat = RenderGraphPlanTests.sessionFormat(),
        renderMode: RenderMode = .automatic,
        gainPlan: GainPlan = GainPlan(),
        version: UInt64 = 1
    ) throws -> RenderGraphPlan {
        try RenderGraphPlanner().makeValidatedPlan(
            RenderGraphPlanRequest(
                version: version,
                sessionFormat: sessionFormat,
                source: source,
                renderMode: renderMode,
                gainPlan: gainPlan,
                createdAtUnixTimeSeconds: nil
            )
        )
    }

    private func planCopy(
        _ plan: RenderGraphPlan,
        source: SourceDescriptor? = nil,
        desktopDownmix: DesktopDownmixPlan? = nil,
        danteRenderer: DanteRenderPlan? = nil,
        validationMessages: [String]? = nil
    ) -> RenderGraphPlan {
        RenderGraphPlan(
            version: plan.version,
            sessionFormat: plan.sessionFormat,
            source: source ?? plan.source,
            renderMode: plan.renderMode,
            desktopDownmix: desktopDownmix ?? plan.desktopDownmix,
            danteRenderer: danteRenderer ?? plan.danteRenderer,
            gainPlan: plan.gainPlan,
            limiterPlan: plan.limiterPlan,
            meterPlan: plan.meterPlan,
            conversionLedger: plan.conversionLedger,
            validationMessages: validationMessages ?? plan.validationMessages,
            createdAtUnixTimeSeconds: plan.createdAtUnixTimeSeconds
        )
    }

    private func stereoSource() -> SourceDescriptor {
        SourceDescriptor(
            id: "stereo",
            kind: .localFile,
            sampleRate: .rate48000,
            channelCount: 2,
            layout: .stereo
        )
    }

    private static func sessionFormat(
        sampleRate: AudioSampleRate = .rate48000,
        physicalDanteChannels: Int = 32
    ) -> AudioSessionFormat {
        AudioSessionFormat(
            sampleRate: sampleRate,
            maxFramesPerBlock: 512,
            dante: DanteOutputFormat(
                physicalChannelCount: physicalDanteChannels,
                sampleRate: sampleRate
            ),
            desktop: DesktopOutputFormat(sampleRate: sampleRate)
        )
    }

    private func sessionFormat(
        sampleRate: AudioSampleRate = .rate48000,
        physicalDanteChannels: Int = 32
    ) -> AudioSessionFormat {
        Self.sessionFormat(sampleRate: sampleRate, physicalDanteChannels: physicalDanteChannels)
    }

    private func renderGraphPlanSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/AudioCore/RenderGraphPlan.swift")
    }
}
