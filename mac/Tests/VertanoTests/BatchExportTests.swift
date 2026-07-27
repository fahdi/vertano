import XCTest

@testable import Vertano

final class BatchExportTests: XCTestCase {
    func testEmptyProducesEmptyString() {
        XCTAssertEqual(BatchExport.combined([]), "")
    }

    func testSingleItemHasFilenameHeaderThenTranscript() {
        XCTAssertEqual(
            BatchExport.combined([(filename: "a.mp3", transcript: "hello world")]),
            "a.mp3\n\nhello world")
    }

    func testMultipleItemsSeparatedByBlankLine() {
        let out = BatchExport.combined([
            (filename: "a.mp3", transcript: "one"),
            (filename: "b.wav", transcript: "two"),
        ])
        XCTAssertEqual(out, "a.mp3\n\none\n\nb.wav\n\ntwo")
    }

    func testSkipsItemsWithNoTranscript() {
        let out = BatchExport.combined([
            (filename: "empty.mp3", transcript: "   "),
            (filename: "b.wav", transcript: "two"),
        ])
        XCTAssertEqual(out, "b.wav\n\ntwo")
    }

    // MARK: - header

    func testHeaderPrependedWhenPresent() {
        let out = BatchExport.combined(
            [(filename: "a.mp3", transcript: "x")], header: "Search results for \"budget\"")
        XCTAssertEqual(out, "Search results for \"budget\"\n\na.mp3\n\nx")
    }

    func testNilHeaderLeavesOutputUnchanged() {
        let out = BatchExport.combined([(filename: "a.mp3", transcript: "x")], header: nil)
        XCTAssertEqual(out, "a.mp3\n\nx")
    }

    func testHeaderNotAddedWhenNothingToExport() {
        XCTAssertEqual(BatchExport.combined([], header: "Search results"), "")
    }
}
