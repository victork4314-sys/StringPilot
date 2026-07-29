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
}
