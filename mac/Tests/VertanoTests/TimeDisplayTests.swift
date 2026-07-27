import XCTest

@testable import Vertano

final class TimeDisplayTests: XCTestCase {
    func testZero() {
        XCTAssertEqual(TimeDisplay.elapsed(0), "00:00")
    }

    func testUnderOneMinute() {
        XCTAssertEqual(TimeDisplay.elapsed(5), "00:05")
    }

    func testMinutesAndSeconds() {
        XCTAssertEqual(TimeDisplay.elapsed(65), "01:05")
    }

    func testJustUnderAnHourStaysMinutesSeconds() {
        XCTAssertEqual(TimeDisplay.elapsed(3599), "59:59")
    }

    func testOneHourGainsHoursField() {
        XCTAssertEqual(TimeDisplay.elapsed(3600), "1:00:00")
    }

    func testHoursMinutesSeconds() {
        XCTAssertEqual(TimeDisplay.elapsed(3665), "1:01:05")
        XCTAssertEqual(TimeDisplay.elapsed(7325), "2:02:05")
    }

    func testNegativeClampsToZero() {
        XCTAssertEqual(TimeDisplay.elapsed(-10), "00:00")
    }
}
