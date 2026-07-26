import Foundation

/// Encodes 16-bit mono PCM samples into an in-memory WAV container.
///
/// The live path already captures 16 kHz mono `Int16`, so it never needed
/// ffmpeg; this also removes the temp-file round-trip (`AVAudioFile` write +
/// read) by handing the bytes straight to the resident server.
enum WAVEncoder {
    static func encode(_ samples: [Int16], sampleRate: Int) -> Data {
        let channels = 1
        let bitsPerSample = 16
        let byteRate = sampleRate * channels * bitsPerSample / 8
        let blockAlign = channels * bitsPerSample / 8
        let dataSize = samples.count * MemoryLayout<Int16>.size

        var data = Data(capacity: 44 + dataSize)
        func append32(_ value: UInt32) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }
        func append16(_ value: UInt16) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }

        data.append(contentsOf: Array("RIFF".utf8))
        append32(UInt32(36 + dataSize))
        data.append(contentsOf: Array("WAVE".utf8))

        data.append(contentsOf: Array("fmt ".utf8))
        append32(16)                       // PCM fmt chunk size
        append16(1)                        // audioFormat = PCM
        append16(UInt16(channels))
        append32(UInt32(sampleRate))
        append32(UInt32(byteRate))
        append16(UInt16(blockAlign))
        append16(UInt16(bitsPerSample))

        data.append(contentsOf: Array("data".utf8))
        append32(UInt32(dataSize))
        for sample in samples {
            withUnsafeBytes(of: sample.littleEndian) { data.append(contentsOf: $0) }
        }
        return data
    }
}
