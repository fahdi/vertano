import XCTest

@testable import Vertano

final class JobRemovalTests: XCTestCase {
    func testQueuedAndFinishedJobsCanBeRemoved() {
        XCTAssertTrue(JobRemoval.canRemove(.queued))
        XCTAssertTrue(JobRemoval.canRemove(.done))
        XCTAssertTrue(JobRemoval.canRemove(.doneWithWarning("note")))
        XCTAssertTrue(JobRemoval.canRemove(.failed("boom")))
    }

    func testActivelyProcessingJobsCannotBeRemoved() {
        // Pulling an in-flight job out from under its running task would
        // corrupt the pump — block it.
        XCTAssertFalse(JobRemoval.canRemove(.converting))
        XCTAssertFalse(JobRemoval.canRemove(.transcribing))
        XCTAssertFalse(
            JobRemoval.canRemove(.translating(language: "es", current: 1, total: 2)))
    }
}
