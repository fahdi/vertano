import XCTest

@testable import Vertano

final class WhisperFlagsTests: XCTestCase {
    // MARK: - D: Metal / flash attention

    func testDefaultsEnableFlashAttention() {
        XCTAssertTrue(WhisperFlags().arguments().contains("-fa"))
    }

    func testDefaultsDoNotDisableGPU() {
        let args = WhisperFlags().arguments()
        XCTAssertFalse(args.contains("-ng"))
        XCTAssertFalse(args.contains("--no-gpu"))
    }

    func testDefaultsDoNotDisableFlashAttention() {
        XCTAssertFalse(WhisperFlags().arguments().contains("-nfa"))
    }

    func testDisablingGPUEmitsNoGPUFlag() {
        var flags = WhisperFlags()
        flags.useGPU = false
        XCTAssertTrue(flags.arguments().contains("-ng"))
    }

    // MARK: - E: latency decoding flags

    func testEmitsThreadCount() {
        let args = WhisperFlags(threads: 8).arguments()
        XCTAssertTrue(consecutive(args, "-t", "8"))
    }

    func testDefaultsToGreedyDecoding() {
        // Beam size 1 / best-of 1 is greedy: fastest, lowest latency per chunk.
        let args = WhisperFlags().arguments()
        XCTAssertTrue(consecutive(args, "-bs", "1"))
        XCTAssertTrue(consecutive(args, "-bo", "1"))
    }

    func testDefaultsToNoTemperatureFallback() {
        XCTAssertTrue(WhisperFlags().arguments().contains("-nf"))
    }

    func testClampThreadsFloorsAtOne() {
        XCTAssertEqual(WhisperFlags.clampThreads(0), 1)
        XCTAssertEqual(WhisperFlags.clampThreads(-5), 1)
    }

    func testClampThreadsCapsAtReasonableMaximum() {
        XCTAssertLessThanOrEqual(WhisperFlags.clampThreads(999), 16)
    }

    // MARK: - streaming / quality flags

    func testDefaultsEnableVADAndNoSpeechAndSuppression() {
        let args = WhisperFlags().arguments()
        XCTAssertTrue(args.contains("--vad"))
        XCTAssertTrue(consecutive(args, "-nth", "0.6"))
        XCTAssertTrue(args.contains("-sns"))
    }

    func testInitialPromptEmittedWhenSet() {
        var flags = WhisperFlags()
        flags.initialPrompt = "prior words"
        XCTAssertTrue(consecutive(flags.arguments(), "--prompt", "prior words"))
    }

    func testInitialPromptOmittedWhenEmptyOrNil() {
        XCTAssertFalse(WhisperFlags().arguments().contains("--prompt"))
        var flags = WhisperFlags()
        flags.initialPrompt = ""
        XCTAssertFalse(flags.arguments().contains("--prompt"))
    }

    // MARK: - helpers

    private func consecutive(_ haystack: [String], _ needle: String...) -> Bool {
        guard !needle.isEmpty, haystack.count >= needle.count else { return false }
        for start in 0...(haystack.count - needle.count) where
            Array(haystack[start..<start + needle.count]) == needle
        {
            return true
        }
        return false
    }
}
