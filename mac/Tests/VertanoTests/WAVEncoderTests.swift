import XCTest

@testable import Vertano

final class WAVEncoderTests: XCTestCase {
    private func u16(_ d: Data, _ offset: Int) -> UInt16 {
        UInt16(d[offset]) | (UInt16(d[offset + 1]) << 8)
    }
    private func u32(_ d: Data, _ offset: Int) -> UInt32 {
        UInt32(d[offset]) | (UInt32(d[offset + 1]) << 8)
            | (UInt32(d[offset + 2]) << 16) | (UInt32(d[offset + 3]) << 24)
    }
    private func ascii(_ d: Data, _ range: Range<Int>) -> String {
        String(decoding: d[range], as: UTF8.self)
    }

    func testHeaderHasRiffWaveMagic() {
        let wav = WAVEncoder.encode([0, 0, 0], sampleRate: 16_000)
        XCTAssertEqual(ascii(wav, 0..<4), "RIFF")
        XCTAssertEqual(ascii(wav, 8..<12), "WAVE")
    }

    func testFmtChunkDescribes16kHzMono16Bit() {
        let wav = WAVEncoder.encode([1, 2, 3, 4], sampleRate: 16_000)
        XCTAssertEqual(ascii(wav, 12..<16), "fmt ")
        XCTAssertEqual(u32(wav, 16), 16)  // PCM fmt chunk size
        XCTAssertEqual(u16(wav, 20), 1)   // audioFormat = PCM
        XCTAssertEqual(u16(wav, 22), 1)   // mono
        XCTAssertEqual(u32(wav, 24), 16_000)  // sample rate
        XCTAssertEqual(u32(wav, 28), 32_000)  // byte rate = 16000*1*2
        XCTAssertEqual(u16(wav, 32), 2)   // block align
        XCTAssertEqual(u16(wav, 34), 16)  // bits per sample
    }

    func testDataChunkSizeMatchesSampleBytes() {
        let samples: [Int16] = [10, -20, 30, -40, 50]
        let wav = WAVEncoder.encode(samples, sampleRate: 16_000)
        XCTAssertEqual(ascii(wav, 36..<40), "data")
        XCTAssertEqual(u32(wav, 40), UInt32(samples.count * 2))
        XCTAssertEqual(wav.count, 44 + samples.count * 2)
    }

    func testRiffChunkSizeIs36PlusData() {
        let samples = [Int16](repeating: 7, count: 100)
        let wav = WAVEncoder.encode(samples, sampleRate: 16_000)
        XCTAssertEqual(u32(wav, 4), UInt32(36 + samples.count * 2))
    }

    func testSamplesEncodedLittleEndian() {
        // 0x0102 -> bytes 0x02, 0x01 ; -1 (0xFFFF) -> 0xFF, 0xFF
        let wav = WAVEncoder.encode([0x0102, -1], sampleRate: 16_000)
        XCTAssertEqual(wav[44], 0x02)
        XCTAssertEqual(wav[45], 0x01)
        XCTAssertEqual(wav[46], 0xFF)
        XCTAssertEqual(wav[47], 0xFF)
    }
}
