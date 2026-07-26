import XCTest

@testable import Vertano

final class ActiveModelTests: XCTestCase {
    func testStoredFilenameWins() {
        let model = WhisperEngine.resolveActiveModel(
            storedFilename: "ggml-large-v3.bin", legacyTierRaw: "efficient")
        XCTAssertEqual(model.filename, "ggml-large-v3.bin")
    }

    func testMigratesFromLegacyTierKeyWhenNoFilenameStored() {
        let model = WhisperEngine.resolveActiveModel(
            storedFilename: nil, legacyTierRaw: "enhanced")
        XCTAssertEqual(model.filename, ModelTier.enhanced.filename)  // ggml-medium.bin
    }

    func testDefaultsToRecommendedWhenNothingStored() {
        let model = WhisperEngine.resolveActiveModel(storedFilename: nil, legacyTierRaw: nil)
        XCTAssertEqual(model.filename, ModelTier.default.filename)  // ggml-small.bin
    }

    func testUnknownStoredFilenameFallsBackToLegacyThenDefault() {
        let viaLegacy = WhisperEngine.resolveActiveModel(
            storedFilename: "ggml-bogus.bin", legacyTierRaw: "maximum")
        XCTAssertEqual(viaLegacy.filename, ModelTier.maximum.filename)

        let viaDefault = WhisperEngine.resolveActiveModel(
            storedFilename: "ggml-bogus.bin", legacyTierRaw: nil)
        XCTAssertEqual(viaDefault.filename, ModelTier.default.filename)
    }

    func testEveryTierMapsToACatalogModel() {
        for tier in ModelTier.allCases {
            XCTAssertEqual(tier.model.filename, tier.filename)
        }
    }
}
