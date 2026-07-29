import XCTest
#if SWIFT_PACKAGE
@testable import StringPilotCore
#else
@testable import StringPilot
#endif

final class StringPitchResolverTests: XCTestCase {
    func testResolvesHighEOpenString() throws {
        let pitch = DetectedPitch(frequency: 329.6276, confidence: 0.95, rms: 0.1, timestamp: 0)
        let result = try XCTUnwrap(StringPitchResolver().resolve(pitch, for: InstrumentProfile.guitarStandard.strings[0]))
        XCTAssertEqual(result.fret, 0)
        XCTAssertEqual(result.midiNote, 64)
    }

    func testResolvesSamePitchToIntendedString() throws {
        let b3 = DetectedPitch(frequency: 246.9417, confidence: 0.9, rms: 0.1, timestamp: 0)
        let stringTwo = try XCTUnwrap(StringPitchResolver().resolve(b3, for: InstrumentProfile.guitarStandard.strings[1]))
        let stringThree = try XCTUnwrap(StringPitchResolver().resolve(b3, for: InstrumentProfile.guitarStandard.strings[2]))
        XCTAssertEqual(stringTwo.fret, 0)
        XCTAssertEqual(stringThree.fret, 4)
    }

    func testCorrectsOctaveErrorInsideStringRange() throws {
        let detectorReturnedOneOctaveLow = DetectedPitch(frequency: 164.8138, confidence: 0.9, rms: 0.1, timestamp: 0)
        let result = try XCTUnwrap(StringPitchResolver().resolve(detectorReturnedOneOctaveLow, for: InstrumentProfile.guitarStandard.strings[0]))
        XCTAssertEqual(result.fret, 0)
    }
}
