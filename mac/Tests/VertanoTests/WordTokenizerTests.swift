import XCTest

@testable import Vertano

final class WordTokenizerTests: XCTestCase {
    func testSplitsOnWhitespace() {
        XCTAssertEqual(WordTokenizer.words("hello world"), ["hello", "world"])
    }

    func testCollapsesRunsAndNewlines() {
        XCTAssertEqual(WordTokenizer.words("a  b\nc"), ["a", "b", "c"])
    }

    func testEmptyIsNoWords() {
        XCTAssertEqual(WordTokenizer.words("   "), [])
    }

    func testKeepsPunctuationWithWord() {
        XCTAssertEqual(WordTokenizer.words("Hello, world."), ["Hello,", "world."])
    }
}
