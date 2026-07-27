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
}
