import XCTest

@testable import Vertano

final class JobFilterTests: XCTestCase {
    func testEmptyQueryMatchesEverything() {
        XCTAssertTrue(JobFilter.matches(filename: "Meeting.mp3", query: ""))
        XCTAssertTrue(JobFilter.matches(filename: "Meeting.mp3", query: "   "))
    }

    func testMatchesCaseInsensitiveSubstring() {
        XCTAssertTrue(JobFilter.matches(filename: "Meeting.mp3", query: "meet"))
        XCTAssertTrue(JobFilter.matches(filename: "Meeting.mp3", query: "MEET"))
    }

    func testDoesNotMatchUnrelatedQuery() {
        XCTAssertFalse(JobFilter.matches(filename: "Meeting.mp3", query: "zoom"))
    }

    func testTrimsQueryWhitespace() {
        XCTAssertTrue(JobFilter.matches(filename: "Meeting.mp3", query: "  meet  "))
    }

    func testMatchesOnExtension() {
        XCTAssertTrue(JobFilter.matches(filename: "audio.wav", query: "wav"))
        XCTAssertFalse(JobFilter.matches(filename: "audio.wav", query: "mp3"))
    }

    // MARK: - content search

    func testEmptyQueryMatchesWithContent() {
        XCTAssertTrue(JobFilter.matches(filename: "a.mp3", transcript: "anything", query: ""))
    }

    func testMatchesTranscriptContentNotJustFilename() {
        XCTAssertTrue(
            JobFilter.matches(
                filename: "interview1.mp3", transcript: "we discussed the budget",
                query: "budget"))
    }

    func testContentMatchIsCaseInsensitive() {
        XCTAssertTrue(
            JobFilter.matches(filename: "a.mp3", transcript: "The Budget", query: "budget"))
    }

    func testStillMatchesFilename() {
        XCTAssertTrue(JobFilter.matches(filename: "budget.mp3", transcript: "", query: "budget"))
    }

    func testNoMatchInEitherFieldIsFalse() {
        XCTAssertFalse(
            JobFilter.matches(filename: "a.mp3", transcript: "hello world", query: "budget"))
    }
}
