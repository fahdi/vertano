import XCTest

@testable import Vertano

final class LiveModelTests: XCTestCase {
    func testLiveUsesInstantModelWhenReady() {
        let choice = WhisperEngine.liveModelSelection(instantReady: true, activeTier: .maximum)
        XCTAssertEqual(choice, .instant)
    }

    func testLiveFallsBackToActiveTierWhenInstantMissing() {
        let choice = WhisperEngine.liveModelSelection(instantReady: false, activeTier: .enhanced)
        XCTAssertEqual(choice, .accurate(.enhanced))
    }

    func testInstantChoiceUsesBaseModel() {
        XCTAssertEqual(LiveModelChoice.instant.filename, "ggml-base.bin")
    }

    func testAccurateChoiceUsesTierFilename() {
        XCTAssertEqual(LiveModelChoice.accurate(.maximum).filename, ModelTier.maximum.filename)
    }

    func testInstantModelIsSmallerThanEfficientTier() {
        // The whole point of C: the live model must be lighter than the
        // lightest user-facing tier, or it buys no speed.
        XCTAssertNotEqual(LiveModel.instantFilename, ModelTier.efficient.filename)
        XCTAssertLessThan(LiveModel.instantMinimumValidSize, ModelTier.efficient.minimumValidSize)
    }

    func testFinalTranscriptionAlwaysUsesActiveTier() {
        // The saved artifact is re-transcribed at the accurate tier regardless
        // of which model drove the live scroll.
        XCTAssertEqual(WhisperEngine.finalTranscriptionTier(activeTier: .maximum), .maximum)
        XCTAssertEqual(WhisperEngine.finalTranscriptionTier(activeTier: .efficient), .efficient)
    }
}
