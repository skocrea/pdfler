@testable import PDFWerkstattCore
import XCTest

final class PageRangeParserTests: XCTestCase {
    func testListsAndRanges() throws {
        XCTAssertEqual(try PageRangeParser.parse("1, 3-5", pageCount: 10), IndexSet([0, 2, 3, 4]))
    }

    func testOpenEndedRanges() throws {
        XCTAssertEqual(try PageRangeParser.parse("8-", pageCount: 10), IndexSet([7, 8, 9]))
        XCTAssertEqual(try PageRangeParser.parse("-2", pageCount: 10), IndexSet([0, 1]))
    }

    func testDashVariantsAndWhitespace() throws {
        XCTAssertEqual(try PageRangeParser.parse(" 2 – 4 ; 6", pageCount: 10), IndexSet([1, 2, 3, 5]))
    }

    func testEmptyInputSelectsNothing() throws {
        XCTAssertEqual(try PageRangeParser.parse("  ", pageCount: 10), IndexSet())
    }

    func testOutOfRangePages() {
        XCTAssertThrowsError(try PageRangeParser.parse("0", pageCount: 10)) { error in
            XCTAssertEqual(error as? PDFWerkstattError, .pageOutOfRange(page: 0, pageCount: 10))
        }
        XCTAssertThrowsError(try PageRangeParser.parse("9-11", pageCount: 10)) { error in
            XCTAssertEqual(error as? PDFWerkstattError, .pageOutOfRange(page: 11, pageCount: 10))
        }
    }

    func testMalformedInput() {
        for input in ["a", "5-3", "1-2-3", "-", "2,x"] {
            XCTAssertThrowsError(try PageRangeParser.parse(input, pageCount: 10), input)
        }
    }
}
