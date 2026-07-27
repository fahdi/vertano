import Foundation
import XCTest

@testable import Vertano

final class SubtitleTests: XCTestCase {
    // MARK: - SRTTimecode

    func testTimecodeZero() {
        XCTAssertEqual(SRTTimecode.format(milliseconds: 0), "00:00:00,000")
    }

    func testTimecodeSecondsAndMillis() {
        XCTAssertEqual(SRTTimecode.format(milliseconds: 2640), "00:00:02,640")
    }

    func testTimecodeHoursMinutesSecondsMillis() {
        XCTAssertEqual(SRTTimecode.format(milliseconds: 3_661_001), "01:01:01,001")
    }

    // MARK: - WhisperJSON parsing

    func testParsesCuesFromWhisperJSON() {
        let json = #"""
        {"transcription":[{"offsets":{"from":0,"to":2640},"text":" Hello there"}]}
        """#.data(using: .utf8)!
        let cues = WhisperJSON.cues(json)
        XCTAssertEqual(cues, [SubtitleCue(startMs: 0, endMs: 2640, text: "Hello there")])
    }

    func testMalformedJSONYieldsNoCues() {
        XCTAssertEqual(WhisperJSON.cues("not json".data(using: .utf8)!), [])
    }

    // MARK: - SRTBuilder

    func testEmptyCuesProduceEmptySRT() {
        XCTAssertEqual(SRTBuilder.build([]), "")
    }

    func testSingleCueBlock() {
        let srt = SRTBuilder.build([SubtitleCue(startMs: 0, endMs: 2640, text: "Hello")])
        XCTAssertEqual(srt, "1\n00:00:00,000 --> 00:00:02,640\nHello")
    }

    func testMultipleCuesAreNumbered() {
        let srt = SRTBuilder.build([
            SubtitleCue(startMs: 0, endMs: 1000, text: "a"),
            SubtitleCue(startMs: 2000, endMs: 3000, text: "b"),
        ])
        XCTAssertEqual(
            srt,
            "1\n00:00:00,000 --> 00:00:01,000\na\n\n2\n00:00:02,000 --> 00:00:03,000\nb")
    }

    func testEmptyTextCuesSkippedAndRenumbered() {
        let srt = SRTBuilder.build([
            SubtitleCue(startMs: 0, endMs: 1000, text: "   "),
            SubtitleCue(startMs: 2000, endMs: 3000, text: "b"),
        ])
        XCTAssertEqual(srt, "1\n00:00:02,000 --> 00:00:03,000\nb")
    }

    // MARK: - output path

    func testSRTPathSwapsExtension() {
        let txt = URL(fileURLWithPath: "/Users/x/Docs/interview.txt")
        XCTAssertEqual(SubtitleOutput.srtURL(for: txt).path, "/Users/x/Docs/interview.srt")
    }
}
