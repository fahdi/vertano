import XCTest

@testable import Vertano

final class TranscriptCleanupTests: XCTestCase {
    func testNormalTextIsReturnedUnchanged() {
        let text = "The quick brown fox jumps over the lazy dog."
        XCTAssertEqual(TranscriptCleanup.collapseWordRuns(text), text)
    }

    func testLegitimateShortRepetitionIsKept() {
        // Below the runaway trigger — leave emphasis intact.
        let text = "no no no I said"
        XCTAssertEqual(TranscriptCleanup.collapseWordRuns(text), text)
    }

    func testRunawayRepetitionIsCapped() {
        // 7 in a row (a classic Whisper silence hallucination) -> capped to 3.
        XCTAssertEqual(
            TranscriptCleanup.collapseWordRuns("no no no no no no no"), "no no no")
    }

    func testRunawayInTheMiddleCollapses() {
        XCTAssertEqual(
            TranscriptCleanup.collapseWordRuns("okay a a a a a a b c"), "okay a a a b c")
    }

    func testUnchangedTextPreservesExactWhitespace() {
        // No runaway -> must not reflow the original spacing/newlines.
        let text = "line one\n\nline  two"
        XCTAssertEqual(TranscriptCleanup.collapseWordRuns(text), text)
    }

    func testEmptyStaysEmpty() {
        XCTAssertEqual(TranscriptCleanup.collapseWordRuns(""), "")
    }
}
