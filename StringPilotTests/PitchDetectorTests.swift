import XCTest
#if SWIFT_PACKAGE
@testable import StringPilotCore
#else
@testable import StringPilot
#endif

final class PitchDetectorTests: XCTestCase {
    func testDetectsLowEOnGuitar() throws {
        let frequency = 82.4069
        let samples = signal(frequency: frequency, sampleRate: 48_000, count: 8_192)
        let result = try XCTUnwrap(YINPitchDetector().detect(samples: samples, sampleRate: 48_000))
        XCTAssertEqual(result.frequency, frequency, accuracy: 0.8)
        XCTAssertGreaterThan(result.confidence, 0.8)
    }

    func testDetectsBassLowEWithHarmonicsAndNoise() throws {
        let frequency = 41.2034
        let samples = signal(
            frequency: frequency,
            sampleRate: 48_000,
            count: 12_288,
            harmonic: 0.28,
            noise: 0.012
        )
        let result = try XCTUnwrap(YINPitchDetector().detect(samples: samples, sampleRate: 48_000))
        XCTAssertEqual(result.frequency, frequency, accuracy: 0.7)
    }

    func testDetectsFiveStringBassLowBWithoutSpecialConfiguration() throws {
        let frequency = 30.8677
        let samples = signal(
            frequency: frequency,
            sampleRate: 48_000,
            count: 16_384,
            harmonic: 0.24,
            noise: 0.006
        )
        let result = try XCTUnwrap(YINPitchDetector().detect(samples: samples, sampleRate: 48_000))
        XCTAssertEqual(result.frequency, frequency, accuracy: 0.55)
        XCTAssertGreaterThan(result.confidence, 0.75)
    }

    func testRejectsSilence() {
        let samples = Array(repeating: Float.zero, count: 4_096)
        XCTAssertNil(YINPitchDetector().detect(samples: samples, sampleRate: 48_000))
    }

    private func signal(
        frequency: Double,
        sampleRate: Double,
        count: Int,
        harmonic: Double = 0.12,
        noise: Double = 0
    ) -> [Float] {
        var state: UInt64 = 0x1234_5678
        return (0..<count).map { index in
            let time = Double(index) / sampleRate
            state = state &* 6_364_136_223_846_793_005 &+ 1
            let random = Double((state >> 33) & 0xFFFF) / 65_535.0 * 2 - 1
            let value = sin(2 * .pi * frequency * time)
                + harmonic * sin(2 * .pi * frequency * 2 * time)
                + noise * random
            return Float(value * 0.35)
        }
    }
}
