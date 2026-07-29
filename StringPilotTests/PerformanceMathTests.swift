import XCTest
#if SWIFT_PACKAGE
@testable import StringPilotCore
#else
@testable import StringPilot
#endif

final class PerformanceMathTests: XCTestCase {
    func testSixteenthNoteIntervalAt120BPM() {
        XCTAssertEqual(NoteSubdivision.sixteenth.intervalSeconds(bpm: 120), 0.125, accuracy: 0.000_001)
    }

    func testProfilesFitDirectXboxMapping() {
        for profile in InstrumentProfile.all {
            XCTAssertLessThanOrEqual(profile.strings.count, XboxInput.allCases.count)
            XCTAssertEqual(Set(profile.strings.map(\.id)).count, profile.strings.count)
        }
    }

    func testPluckedStringGeneratorProducesFiniteDecayingSignal() {
        let output = PluckedStringGenerator().generate(.init(
            frequency: 110,
            sampleRate: 48_000,
            duration: 0.8,
            velocity: 0.8,
            palmMute: 0.2,
            seed: 42
        ))
        XCTAssertEqual(output.count, 38_400)
        XCTAssertTrue(output.allSatisfy { $0.isFinite })
        let early = output.prefix(4_000).map { abs(Double($0)) }.reduce(0, +)
        let late = output.suffix(4_000).map { abs(Double($0)) }.reduce(0, +)
        XCTAssertGreaterThan(early, late)
    }

    func testCapturedAttackRejectsSilence() {
        let prepared = CapturedAttackProcessor().prepare(
            samples: Array(repeating: 0, count: 4_096),
            sampleRate: 48_000,
            sourceFrequency: 110
        )
        XCTAssertNil(prepared)
    }

    func testCapturedAttackIsTrimmedNormalizedAndRenderable() throws {
        let sampleRate = 48_000.0
        let frequency = 196.0
        var input = Array(repeating: Float.zero, count: 12_000)
        for frame in 1_200..<input.count {
            let time = Double(frame - 1_200) / sampleRate
            let envelope = exp(-time * 9)
            input[frame] = Float(sin(2 * Double.pi * frequency * time) * envelope * 0.035)
        }

        let processor = CapturedAttackProcessor()
        let prepared = try XCTUnwrap(processor.prepare(
            samples: input,
            sampleRate: sampleRate,
            sourceFrequency: frequency
        ))
        XCTAssertLessThan(prepared.samples.count, input.count)
        XCTAssertGreaterThan(prepared.samples.count, 1_000)
        XCTAssertTrue(prepared.samples.allSatisfy { $0.isFinite })
        XCTAssertLessThanOrEqual(prepared.samples.map { abs($0) }.max() ?? 0, 0.901)
        XCTAssertLessThan(abs(prepared.samples.first ?? 1), 0.1)
        XCTAssertLessThan(abs(prepared.samples.last ?? 1), 0.01)

        let rendered = processor.render(
            prepared,
            targetSampleRate: sampleRate,
            targetFrequency: 220,
            frameCount: 8_000,
            velocity: 0.8,
            seed: 99
        )
        XCTAssertEqual(rendered.count, 8_000)
        XCTAssertTrue(rendered.allSatisfy { $0.isFinite })
        XCTAssertGreaterThan(rendered.map { abs(Double($0)) }.reduce(0, +), 1)

        let model = PluckedStringGenerator().generate(.init(
            frequency: 220,
            sampleRate: sampleRate,
            duration: Double(rendered.count) / sampleRate,
            velocity: 0.8,
            palmMute: 0,
            seed: 99
        ))
        let blended = processor.blend(model: model, captured: rendered)
        XCTAssertEqual(blended.count, model.count)
        XCTAssertTrue(blended.allSatisfy { $0.isFinite })
        XCTAssertNotEqual(blended, model)
    }
}
