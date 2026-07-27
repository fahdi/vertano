import XCTest

@testable import Vertano

final class QueueStatsTests: XCTestCase {
    func testEmptyQueueHasNoSummary() {
        XCTAssertNil(QueueStats.summary(statuses: []))
    }

    func testNothingDoneYet() {
        XCTAssertEqual(QueueStats.summary(statuses: [.queued, .queued]), "0 of 2 done")
    }

    func testCountsDoneJobs() {
        XCTAssertEqual(
            QueueStats.summary(statuses: [.done, .queued, .done]), "2 of 3 done")
    }

    func testDoneWithWarningCountsAsDone() {
        XCTAssertEqual(
            QueueStats.summary(statuses: [.doneWithWarning("x")]), "1 of 1 done")
    }

    func testInProgressIsNotDone() {
        XCTAssertEqual(
            QueueStats.summary(statuses: [.transcribing, .converting,
                .translating(language: "es", current: 1, total: 2)]),
            "0 of 3 done")
    }

    func testAppendsFailedCount() {
        XCTAssertEqual(
            QueueStats.summary(statuses: [.done, .failed("boom")]), "1 of 2 done, 1 failed")
    }

    // MARK: - total words

    func testTotalWordsSumsTranscripts() {
        XCTAssertEqual(QueueStats.totalWords(transcripts: ["hello world", "one two three"]), 5)
    }

    func testTotalWordsIgnoresEmpty() {
        XCTAssertEqual(QueueStats.totalWords(transcripts: ["", "   ", "hi"]), 1)
    }

    func testTotalWordsLabelNilWhenNoWords() {
        XCTAssertNil(QueueStats.totalWordsLabel(transcripts: []))
        XCTAssertNil(QueueStats.totalWordsLabel(transcripts: ["", " "]))
    }

    func testTotalWordsLabelGroupsThousands() {
        let big = [String(repeating: "word ", count: 2500)]
        XCTAssertEqual(QueueStats.totalWordsLabel(transcripts: big), "2,500 words")
    }
}
