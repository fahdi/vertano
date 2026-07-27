import XCTest

@testable import Vertano

final class SearchSnippetTests: XCTestCase {
    func testNilWhenQueryEmpty() {
        XCTAssertNil(SearchSnippet.excerpt(text: "hello world", query: "  "))
    }

    func testNilWhenNotFound() {
        XCTAssertNil(SearchSnippet.excerpt(text: "hello world", query: "budget"))
    }

    func testExcerptCentersOnMatchWithEllipses() {
        let out = SearchSnippet.excerpt(text: "abcdefGHIJKLmnopqr", query: "GHIJKL", radius: 3)
        XCTAssertEqual(out, "…defGHIJKLmno…")
    }

    func testNoLeadingEllipsisAtStart() {
        let out = SearchSnippet.excerpt(text: "GHIJKLmnop", query: "GHIJKL", radius: 3)
        XCTAssertEqual(out, "GHIJKLmno…")
    }

    func testNoTrailingEllipsisAtEnd() {
        // Match ends at the text end -> no trailing ellipsis; the long prefix
        // is clipped -> leading ellipsis present.
        let out = SearchSnippet.excerpt(text: "abcdefghGHIJKL", query: "GHIJKL", radius: 3)
        XCTAssertEqual(out, "…fghGHIJKL")
    }

    func testCaseInsensitiveKeepsOriginalCasing() {
        let out = SearchSnippet.excerpt(text: "the Budget report", query: "budget", radius: 3)
        XCTAssertNotNil(out)
        XCTAssertTrue(out!.contains("Budget"))
    }

    func testNewlinesFlattenedToSpaces() {
        let out = SearchSnippet.excerpt(text: "one\nGHIJKL\ntwo", query: "GHIJKL", radius: 2)
        XCTAssertFalse(out!.contains("\n"))
    }
}
