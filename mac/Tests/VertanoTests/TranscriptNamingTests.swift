import XCTest

@testable import Vertano

final class TranscriptNamingTests: XCTestCase {
    private let fallback = "Recording 2026-07-27 at 14.30.00"

    func testEmptyTranscriptUsesFallback() {
        XCTAssertEqual(TranscriptNaming.baseName(transcript: "", fallback: fallback), fallback)
    }

    func testWhitespaceOnlyTranscriptUsesFallback() {
        XCTAssertEqual(
            TranscriptNaming.baseName(transcript: "   \n\t ", fallback: fallback), fallback)
    }

    func testShortTranscriptBecomesTheName() {
        XCTAssertEqual(
            TranscriptNaming.baseName(transcript: "Hello world", fallback: fallback), "Hello world")
    }

    func testStripsPathSeparatorsAndIllegalCharacters() {
        XCTAssertEqual(
            TranscriptNaming.baseName(transcript: "Meeting: Q3/Q4 plan", fallback: fallback),
            "Meeting Q3 Q4 plan")
    }

    func testCollapsesWhitespaceAndNewlines() {
        XCTAssertEqual(
            TranscriptNaming.baseName(transcript: "Hello   world\n\nthere", fallback: fallback),
            "Hello world there")
    }

    func testTruncatesLongTranscriptToMaxLength() {
        let long = String(repeating: "word ", count: 50)
        let name = TranscriptNaming.baseName(transcript: long, fallback: fallback)
        XCTAssertLessThanOrEqual(name.count, TranscriptNaming.maxLength)
        XCTAssertFalse(name.hasSuffix(" "))
    }

    func testSingleWordLongerThanMaxIsHardTruncated() {
        let name = TranscriptNaming.baseName(
            transcript: String(repeating: "a", count: 100), fallback: fallback)
        XCTAssertEqual(name.count, TranscriptNaming.maxLength)
    }
}
