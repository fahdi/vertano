import XCTest

@testable import Vertano

final class SearchSummaryTests: XCTestCase {
    func testNilForEmptyQuery() {
        XCTAssertNil(SearchSummary.summary(texts: ["hello world"], query: "  "))
    }

    func testNilWhenNoMatches() {
        XCTAssertNil(SearchSummary.summary(texts: ["hello", "world"], query: "budget"))
    }

    func testCountsMatchesAndFiles() {
        let texts = ["the budget was tight", "budget budget", "no mention here"]
        XCTAssertEqual(SearchSummary.summary(texts: texts, query: "budget"), "3 matches in 2 files")
    }

    func testSingularForOneMatchOneFile() {
        XCTAssertEqual(
            SearchSummary.summary(texts: ["one budget", "nothing"], query: "budget"),
            "1 match in 1 file")
    }

    func testCaseInsensitive() {
        XCTAssertEqual(
            SearchSummary.summary(texts: ["The Budget"], query: "budget"), "1 match in 1 file")
    }
}
