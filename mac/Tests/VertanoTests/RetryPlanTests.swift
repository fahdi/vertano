import XCTest

@testable import Vertano

final class RetryPlanTests: XCTestCase {
    func testResetTurnsFailedIntoQueued() {
        XCTAssertEqual(RetryPlan.reset(.failed("network died")), .queued)
    }

    func testResetLeavesNonFailedUntouched() {
        XCTAssertEqual(RetryPlan.reset(.done), .done)
        XCTAssertEqual(RetryPlan.reset(.queued), .queued)
        XCTAssertEqual(RetryPlan.reset(.transcribing), .transcribing)
        XCTAssertEqual(RetryPlan.reset(.doneWithWarning("note")), .doneWithWarning("note"))
    }

    func testRetriableCountsOnlyFailures() {
        XCTAssertEqual(RetryPlan.retriableCount([.failed("a"), .done, .failed("b"), .queued]), 2)
        XCTAssertEqual(RetryPlan.retriableCount([.done, .queued]), 0)
        XCTAssertEqual(RetryPlan.retriableCount([]), 0)
    }
}
