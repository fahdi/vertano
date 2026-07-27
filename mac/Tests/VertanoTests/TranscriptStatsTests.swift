import XCTest

@testable import Vertano

final class TranscriptStatsTests: XCTestCase {
    func testEmptyTextHasNoWords() {
        XCTAssertEqual(TranscriptStats.wordCount(""), 0)
        XCTAssertEqual(TranscriptStats.wordCount("   \n\t "), 0)
    }

    func testCountsSingleWord() {
        XCTAssertEqual(TranscriptStats.wordCount("hello"), 1)
    }

    func testCountsWordsAcrossWhitespaceAndNewlines() {
        XCTAssertEqual(TranscriptStats.wordCount("a  b\nc\td"), 4)
    }

    func testIgnoresLeadingAndTrailingWhitespace() {
        XCTAssertEqual(TranscriptStats.wordCount("  hello world  "), 2)
    }

    func testLabelUsesSingularForOneWord() {
        XCTAssertEqual(TranscriptStats.label(for: "hello"), "1 word")
    }

    func testLabelUsesPluralForZeroAndMany() {
        XCTAssertEqual(TranscriptStats.label(for: ""), "0 words")
        XCTAssertEqual(TranscriptStats.label(for: "hello world"), "2 words")
    }

    func testLabelGroupsThousands() {
        let text = String(repeating: "word ", count: 1234)
        XCTAssertEqual(TranscriptStats.label(for: text), "1,234 words")
    }

    // MARK: - reading time

    func testNoWordsHasZeroReadingTime() {
        XCTAssertEqual(TranscriptStats.readingTimeMinutes(wordCount: 0), 0)
        XCTAssertEqual(TranscriptStats.readingTimeLabel(for: ""), "")
    }

    func testShortTextRoundsUpToOneMinute() {
        // ~200 wpm; anything from 1..200 words is "~1 min read".
        XCTAssertEqual(TranscriptStats.readingTimeMinutes(wordCount: 1), 1)
        XCTAssertEqual(TranscriptStats.readingTimeMinutes(wordCount: 200), 1)
    }

    func testReadingTimeRoundsUpPerTwoHundredWords() {
        XCTAssertEqual(TranscriptStats.readingTimeMinutes(wordCount: 201), 2)
        XCTAssertEqual(TranscriptStats.readingTimeMinutes(wordCount: 400), 2)
        XCTAssertEqual(TranscriptStats.readingTimeMinutes(wordCount: 401), 3)
    }

    func testReadingTimeLabelFormat() {
        let text = String(repeating: "word ", count: 500)
        XCTAssertEqual(TranscriptStats.readingTimeLabel(for: text), "~3 min read")
    }
}
