import XCTest

@testable import Vertano

final class LiveChunkingTests: XCTestCase {
    func testSampleCountIsSecondsTimesRate() {
        XCTAssertEqual(LiveChunking.sampleCount(seconds: 5, sampleRate: 16_000), 80_000)
        XCTAssertEqual(LiveChunking.sampleCount(seconds: 15, sampleRate: 16_000), 240_000)
    }

    func testDefaultChunkIsShorterThanLegacyFifteenSeconds() {
        // The whole point of F: get text on screen sooner than the old 15 s.
        XCTAssertLessThan(LiveChunking.defaultChunkSeconds, 15)
    }

    func testDefaultChunkSampleCountAtWhisperRate() {
        XCTAssertEqual(
            LiveChunking.defaultChunkSampleCount(sampleRate: 16_000),
            LiveChunking.defaultChunkSeconds * 16_000)
    }

    func testResidentServerAllowsShortChunksButCLIStaysLong() {
        // Short chunks are only viable with the resident server; the CLI
        // fallback reloads the model per chunk, so it keeps the long chunk.
        XCTAssertEqual(
            LiveChunking.chunkSampleCount(residentServer: true, sampleRate: 16_000),
            LiveChunking.defaultChunkSampleCount(sampleRate: 16_000))
        XCTAssertEqual(
            LiveChunking.chunkSampleCount(residentServer: false, sampleRate: 16_000),
            LiveChunking.legacyChunkSampleCount(sampleRate: 16_000))
    }
}
