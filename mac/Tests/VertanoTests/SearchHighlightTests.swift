import Foundation
import XCTest

@testable import Vertano

final class SearchHighlightTests: XCTestCase {
    func testEmptyQueryHasNoRanges() {
        XCTAssertTrue(SearchHighlight.matchRanges(in: "hello world", query: "  ").isEmpty)
    }

    func testMissingTermHasNoRanges() {
        XCTAssertTrue(SearchHighlight.matchRanges(in: "hello world", query: "budget").isEmpty)
    }

    func testFindsEveryOccurrence() {
        let text = "the cat and the dog"
        let ranges = SearchHighlight.matchRanges(in: text, query: "the")
        XCTAssertEqual(ranges.count, 2)
        let ns = text as NSString
        XCTAssertEqual(ns.substring(with: ranges[0]), "the")
        XCTAssertEqual(ranges[0].location, 0)
        XCTAssertEqual(ranges[1].location, 12)
    }

    func testCaseInsensitive() {
        XCTAssertEqual(SearchHighlight.matchRanges(in: "The THE the", query: "the").count, 3)
    }
}
