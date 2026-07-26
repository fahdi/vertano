import XCTest

@testable import Vertano

final class WhisperServerTests: XCTestCase {
    // MARK: - Response parsing

    func testParseInferenceExtractsTextField() throws {
        let json = #"{"text":"  hello world  "}"#.data(using: .utf8)!
        XCTAssertEqual(try WhisperServer.parseInference(json), "hello world")
    }

    func testParseInferenceStripsBlankAudioMarker() throws {
        let json = #"{"text":"[BLANK_AUDIO]"}"#.data(using: .utf8)!
        XCTAssertEqual(try WhisperServer.parseInference(json), "")
    }

    func testParseInferenceThrowsOnMalformedJSON() {
        let junk = "not json".data(using: .utf8)!
        XCTAssertThrowsError(try WhisperServer.parseInference(junk))
    }

    // MARK: - Launch arguments

    func testLaunchArgumentsIncludeModelHostAndPort() {
        let args = WhisperServer.launchArguments(
            modelPath: "/models/ggml-base.bin", host: "127.0.0.1", port: 8181, extraFlags: [])
        XCTAssertTrue(args.contains("/models/ggml-base.bin"))
        XCTAssertTrue(consecutive(args, "-m", "/models/ggml-base.bin"))
        XCTAssertTrue(consecutive(args, "--host", "127.0.0.1"))
        XCTAssertTrue(consecutive(args, "--port", "8181"))
    }

    func testLaunchArgumentsAppendExtraFlags() {
        let args = WhisperServer.launchArguments(
            modelPath: "/m.bin", host: "127.0.0.1", port: 9000, extraFlags: ["-fa", "-t", "8"])
        XCTAssertTrue(consecutive(args, "-fa"))
        XCTAssertTrue(consecutive(args, "-t", "8"))
    }

    // MARK: - Multipart body

    func testMultipartBodyCarriesWavBytesAndFields() throws {
        let wav = Data([0x52, 0x49, 0x46, 0x46, 0xDE, 0xAD, 0xBE, 0xEF])  // "RIFF" + marker
        let body = WhisperServer.multipartBody(
            boundary: "B", wav: wav, language: "es", translateToEnglish: true)
        let string = String(decoding: body, as: UTF8.self)

        XCTAssertTrue(string.contains("name=\"file\"; filename=\"chunk.wav\""))
        XCTAssertTrue(string.contains("name=\"language\"\r\n\r\nes"))
        XCTAssertTrue(string.contains("name=\"translate\"\r\n\r\ntrue"))
        XCTAssertTrue(string.contains("--B--"))  // closing boundary
        XCTAssertTrue(body.range(of: wav) != nil)  // raw audio bytes present
    }

    // MARK: - Inference URL

    func testInferenceURLTargetsLoopbackInferenceEndpoint() {
        let url = WhisperServer.inferenceURL(host: "127.0.0.1", port: 8181)
        XCTAssertEqual(url.absoluteString, "http://127.0.0.1:8181/inference")
    }

    // MARK: - helpers

    /// True if `needle` appears as a contiguous run inside `haystack`.
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
