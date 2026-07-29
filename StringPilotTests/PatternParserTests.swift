import XCTest
#if SWIFT_PACKAGE
@testable import StringPilotCore
#else
@testable import StringPilot
#endif

final class PatternParserTests: XCTestCase {
    func testParsesStringsRestsAndAccents() throws {
        let result = try PatternParser().parse("1, 2 | - 3! rest", maximumString: 6)
        XCTAssertEqual(result.map(\.stringNumber), [1, 2, nil, 3, nil])
        XCTAssertEqual(result.map(\.accent), [false, false, false, true, false])
    }

    func testRejectsOutOfRangeString() {
        XCTAssertThrowsError(try PatternParser().parse("1 7", maximumString: 6)) { error in
            XCTAssertEqual(error as? PatternParseError, .stringOutOfRange(7, maximum: 6))
        }
    }

    func testRoundTripRendering() throws {
        let parser = PatternParser()
        let parsed = try parser.parse("1 2 - 4!", maximumString: 6)
        XCTAssertEqual(parser.render(parsed), "1 2 - 4!")
    }
}
