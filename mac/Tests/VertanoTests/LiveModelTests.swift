import XCTest

@testable import Vertano

final class LiveModelTests: XCTestCase {
    private let maximumModel = ModelTier.maximum.model
    private let enhancedModel = ModelTier.enhanced.model
    private let efficientModel = ModelTier.efficient.model

    func testLiveUsesInstantModelWhenReady() {
        let choice = WhisperEngine.liveModelSelection(instantReady: true, active: maximumModel)
        XCTAssertEqual(choice, .instant)
    }

    func testLiveFallsBackToActiveModelWhenInstantMissing() {
        let choice = WhisperEngine.liveModelSelection(instantReady: false, active: enhancedModel)
        XCTAssertEqual(choice, .accurate(enhancedModel))
    }

    func testInstantChoiceUsesBaseModel() {
        XCTAssertEqual(LiveModelChoice.instant.filename, "ggml-base.bin")
    }

    func testAccurateChoiceUsesModelFilename() {
        XCTAssertEqual(LiveModelChoice.accurate(maximumModel).filename, maximumModel.filename)
    }

    func testInstantModelIsSmallerThanEfficientTier() {
        XCTAssertNotEqual(LiveModel.instantFilename, ModelTier.efficient.filename)
        XCTAssertLessThan(LiveModel.instantMinimumValidSize, ModelTier.efficient.minimumValidSize)
    }

    func testFinalTranscriptionAlwaysUsesActiveModel() {
        XCTAssertEqual(WhisperEngine.finalTranscriptionModel(active: maximumModel), maximumModel)
        XCTAssertEqual(WhisperEngine.finalTranscriptionModel(active: efficientModel), efficientModel)
    }
}
