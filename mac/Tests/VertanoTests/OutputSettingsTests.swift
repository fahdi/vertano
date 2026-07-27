import XCTest

@testable import Vertano

final class OutputSettingsTests: XCTestCase {
    func testSubtitlesDefaultOnWhenUnset() {
        XCTAssertTrue(OutputSettings.resolveSubtitlesEnabled(stored: nil))
    }

    func testStoredPreferenceWins() {
        XCTAssertFalse(OutputSettings.resolveSubtitlesEnabled(stored: false))
        XCTAssertTrue(OutputSettings.resolveSubtitlesEnabled(stored: true))
    }
}
