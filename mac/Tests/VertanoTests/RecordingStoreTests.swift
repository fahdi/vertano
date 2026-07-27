import XCTest

@testable import Vertano

final class RecordingStoreTests: XCTestCase {
    func testDefaultFolderIsVertanoUnderDocuments() {
        let folder = RecordingStore.defaultFolder
        XCTAssertEqual(folder.lastPathComponent, "Vertano")
        XCTAssertTrue(folder.deletingLastPathComponent().lastPathComponent == "Documents")
    }

    func testDefaultFolderIsADirectoryURL() {
        XCTAssertTrue(RecordingStore.defaultFolder.hasDirectoryPath)
    }
}
