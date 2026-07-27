import XCTest

@testable import Vertano

final class TranscriptReflowTests: XCTestCase {
    func testJoinsSegmentLinesIntoOneParagraph() {
        XCTAssertEqual(TranscriptReflow.flow("one\ntwo\nthree"), "one two three")
    }

    func testBlankLineStartsANewParagraph() {
        XCTAssertEqual(TranscriptReflow.flow("a\nb\n\nc"), "a b\n\nc")
    }

    func testTrimsPerLineWhitespace() {
        XCTAssertEqual(TranscriptReflow.flow("  a  \n  b "), "a b")
    }

    func testSingleLineUnchanged() {
        XCTAssertEqual(TranscriptReflow.flow("just one line"), "just one line")
    }

    func testEmptyStaysEmpty() {
        XCTAssertEqual(TranscriptReflow.flow(""), "")
    }

    // MARK: - preference

    func testFlowDefaultsOff() {
        XCTAssertFalse(OutputSettings.resolveFlowParagraphs(stored: nil))
    }

    func testFlowStoredPreferenceWins() {
        XCTAssertTrue(OutputSettings.resolveFlowParagraphs(stored: true))
    }
}
