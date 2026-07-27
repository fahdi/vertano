import XCTest

@testable import Vertano

final class SaveExportTests: XCTestCase {
    func testDefaultFilenameWhenNoSearch() {
        XCTAssertEqual(SaveExport.filename(query: ""), "Vertano Transcripts.txt")
        XCTAssertEqual(SaveExport.filename(query: "   "), "Vertano Transcripts.txt")
    }

    func testFilenameIncludesSearchTerm() {
        XCTAssertEqual(SaveExport.filename(query: "budget"), "Vertano - budget.txt")
    }

    func testFilenameSanitizesIllegalCharacters() {
        XCTAssertEqual(SaveExport.filename(query: "a/b:c"), "Vertano - a b c.txt")
    }
}
