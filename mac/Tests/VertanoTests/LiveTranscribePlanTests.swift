import XCTest

@testable import Vertano

final class LiveTranscribePlanTests: XCTestCase {
    func testServerWithInstantModelUsesShortChunksAndInstant() {
        let plan = LiveTranscribePlan.make(
            serverAvailable: true, instantReady: true, activeTier: .maximum, sampleRate: 16_000)
        XCTAssertTrue(plan.useServer)
        XCTAssertEqual(plan.liveModel, .instant)
        XCTAssertEqual(plan.chunkSampleCount, LiveChunking.defaultChunkSampleCount(sampleRate: 16_000))
    }

    func testServerWithoutInstantModelFallsBackToActiveTier() {
        let plan = LiveTranscribePlan.make(
            serverAvailable: true, instantReady: false, activeTier: .enhanced, sampleRate: 16_000)
        XCTAssertTrue(plan.useServer)
        XCTAssertEqual(plan.liveModel, .accurate(.enhanced))
    }

    func testNoServerKeepsLongChunks() {
        let plan = LiveTranscribePlan.make(
            serverAvailable: false, instantReady: true, activeTier: .efficient, sampleRate: 16_000)
        XCTAssertFalse(plan.useServer)
        XCTAssertEqual(plan.chunkSampleCount, LiveChunking.legacyChunkSampleCount(sampleRate: 16_000))
    }
}
