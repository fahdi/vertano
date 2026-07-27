import XCTest

@testable import Vertano

final class QueueControlTests: XCTestCase {
    func testEmptyHasNoPendingWork() {
        XCTAssertFalse(QueueControl.hasPendingWork([]))
    }

    func testAllFinishedHasNoPendingWork() {
        XCTAssertFalse(QueueControl.hasPendingWork([.done, .failed("x"), .doneWithWarning("n")]))
    }

    func testQueuedCountsAsPending() {
        XCTAssertTrue(QueueControl.hasPendingWork([.done, .queued]))
    }

    func testActiveStatesCountAsPending() {
        XCTAssertTrue(QueueControl.hasPendingWork([.transcribing]))
        XCTAssertTrue(QueueControl.hasPendingWork([.converting]))
        XCTAssertTrue(
            QueueControl.hasPendingWork([.translating(language: "es", current: 1, total: 3)]))
    }
}
