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

    // MARK: - repeated lines

    func testCollapsesManyIdenticalConsecutiveLines() {
        XCTAssertEqual(
            TranscriptCleanup.collapseRepeatedLines("Thank you.\nThank you.\nThank you.\nThank you."),
            "Thank you.")
    }

    func testCollapsesRepeatedLineRunInMiddle() {
        XCTAssertEqual(
            TranscriptCleanup.collapseRepeatedLines("intro\nloop\nloop\nloop\noutro"),
            "intro\nloop\noutro")
    }

    func testTwoIdenticalLinesAreKept() {
        // A one-time repeat is plausibly real; only runaway loops collapse.
        let text = "yes\nyes"
        XCTAssertEqual(TranscriptCleanup.collapseRepeatedLines(text), text)
    }

    func testDistinctLinesUnchanged() {
        let text = "one\ntwo\nthree"
        XCTAssertEqual(TranscriptCleanup.collapseRepeatedLines(text), text)
    }

    func testNoRepeatPreservesExactText() {
        let text = "single line with  spaces"
        XCTAssertEqual(TranscriptCleanup.collapseRepeatedLines(text), text)
    }

    // MARK: - non-speech markers

    func testRemovesInlineMusicMarker() {
        XCTAssertEqual(
            TranscriptCleanup.stripNonSpeechMarkers("Hello [Music] world"), "Hello world")
    }

    func testRemovesLeadingParentheticalApplause() {
        XCTAssertEqual(
            TranscriptCleanup.stripNonSpeechMarkers("(applause) Thank you"), "Thank you")
    }

    func testRemovesBlankAudioMarkerEntirely() {
        XCTAssertEqual(TranscriptCleanup.stripNonSpeechMarkers("[BLANK_AUDIO]"), "")
    }

    func testKeepsInaudibleAndOtherContentMarkers() {
        // Not a non-speech *event* — preserve the signal.
        let text = "He said [inaudible] something"
        XCTAssertEqual(TranscriptCleanup.stripNonSpeechMarkers(text), text)
    }

    func testUnbracketedKeywordUntouched() {
        let text = "Music was playing in the background"
        XCTAssertEqual(TranscriptCleanup.stripNonSpeechMarkers(text), text)
    }

    func testNoMarkersPreservesExactText() {
        let text = "line one\n\nline  two"
        XCTAssertEqual(TranscriptCleanup.stripNonSpeechMarkers(text), text)
    }
}
