import XCTest

@testable import Vertano

final class SpeakingRateTests: XCTestCase {
    func testNilForZeroOrNegativeTime() {
        XCTAssertNil(SpeakingRate.wordsPerMinute(words: 50, seconds: 0))
        XCTAssertNil(SpeakingRate.wordsPerMinute(words: 50, seconds: -3))
    }

    func testNilBeforeWarmupWindow() {
        // Too little audio to be meaningful — avoid a jumpy early number.
        XCTAssertNil(SpeakingRate.wordsPerMinute(words: 10, seconds: 2))
    }

    func testComputesRateOverAMinute() {
        XCTAssertEqual(SpeakingRate.wordsPerMinute(words: 150, seconds: 60), 150)
    }

    func testScalesForPartialMinute() {
        XCTAssertEqual(SpeakingRate.wordsPerMinute(words: 100, seconds: 30), 200)
    }

    func testRoundsToNearestWholeWord() {
        // 10 words in 7s -> 85.7 -> 86 wpm
        XCTAssertEqual(SpeakingRate.wordsPerMinute(words: 10, seconds: 7), 86)
    }

    func testLabelNilWhenRateUnavailable() {
        XCTAssertNil(SpeakingRate.label(words: 5, seconds: 1))
        XCTAssertEqual(SpeakingRate.label(words: 150, seconds: 60), "150 wpm")
    }
}
