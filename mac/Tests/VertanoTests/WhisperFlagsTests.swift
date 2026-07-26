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
}
