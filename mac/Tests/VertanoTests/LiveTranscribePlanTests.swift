import XCTest

@testable import Vertano

final class LiveTranscribePlanTests: XCTestCase {
    private let maximumModel = ModelTier.maximum.model
    private let enhancedModel = ModelTier.enhanced.model
    private let efficientModel = ModelTier.efficient.model

    func testServerWithInstantModelUsesShortChunksAndInstant() {
        let plan = LiveTranscribePlan.make(
            serverAvailable: true, instantReady: true, active: maximumModel, sampleRate: 16_000)
        XCTAssertTrue(plan.useServer)
        XCTAssertEqual(plan.liveModel, .instant)
        XCTAssertEqual(plan.chunkSampleCount, LiveChunking.defaultChunkSampleCount(sampleRate: 16_000))
    }

    func testServerWithoutInstantModelFallsBackToActiveModel() {
        let plan = LiveTranscribePlan.make(
            serverAvailable: true, instantReady: false, active: enhancedModel, sampleRate: 16_000)
        XCTAssertTrue(plan.useServer)
        XCTAssertEqual(plan.liveModel, .accurate(enhancedModel))
    }

    func testNoServerKeepsLongChunks() {
        let plan = LiveTranscribePlan.make(
            serverAvailable: false, instantReady: true, active: efficientModel, sampleRate: 16_000)
        XCTAssertFalse(plan.useServer)
        XCTAssertEqual(plan.chunkSampleCount, LiveChunking.legacyChunkSampleCount(sampleRate: 16_000))
    }
}
