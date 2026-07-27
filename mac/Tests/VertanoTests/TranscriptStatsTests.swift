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
}
