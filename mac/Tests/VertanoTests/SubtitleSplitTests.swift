import XCTest

@testable import Vertano

final class SubtitleSplitTests: XCTestCase {
    func testShortCueIsUnchanged() {
        let cues = [SubtitleCue(startMs: 0, endMs: 1000, text: "hi there")]
        XCTAssertEqual(SubtitleSplit.wrap(cues, maxChars: 40), cues)
    }

    func testWrapWordsIsGreedyAtWordBoundaries() {
        XCTAssertEqual(
            SubtitleSplit.wrapWords("one two three", maxChars: 7), ["one two", "three"])
    }

    func testLongCueSplitsWithoutBreakingWords() {
        let cue = SubtitleCue(startMs: 0, endMs: 900, text: "one two three four five six")
        let out = SubtitleSplit.wrap([cue], maxChars: 10)

        XCTAssertGreaterThan(out.count, 1)
        for piece in out { XCTAssertLessThanOrEqual(piece.text.count, 10) }
        // No content lost or reordered.
        XCTAssertEqual(out.map(\.text).joined(separator: " "), "one two three four five six")
    }

    func testSplitTimingIsContiguousAndCoversOriginalSpan() {
        let cue = SubtitleCue(startMs: 0, endMs: 900, text: "one two three four five six")
        let out = SubtitleSplit.wrap([cue], maxChars: 10)

        XCTAssertEqual(out.first?.startMs, 0)
        XCTAssertEqual(out.last?.endMs, 900)
        for i in 1..<out.count {
            XCTAssertEqual(out[i].startMs, out[i - 1].endMs)
        }
    }
}
