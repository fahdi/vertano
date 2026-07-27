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

    // MARK: - match count

    func testMatchCountZeroForEmptyOrMissing() {
        XCTAssertEqual(SearchSnippet.matchCount(text: "hello", query: "  "), 0)
        XCTAssertEqual(SearchSnippet.matchCount(text: "hello", query: "budget"), 0)
    }

    func testMatchCountCountsOccurrences() {
        XCTAssertEqual(
            SearchSnippet.matchCount(text: "the cat sat on the mat", query: "the"), 2)
    }

    func testMatchCountIsCaseInsensitive() {
        XCTAssertEqual(SearchSnippet.matchCount(text: "The THE the", query: "the"), 3)
    }

    func testMatchCountLabelSingularAndPlural() {
        XCTAssertNil(SearchSnippet.matchCountLabel(text: "hello", query: "x"))
        XCTAssertEqual(SearchSnippet.matchCountLabel(text: "one two", query: "one"), "1 match")
        XCTAssertEqual(
            SearchSnippet.matchCountLabel(text: "aa aa aa", query: "aa"), "3 matches")
    }
}
