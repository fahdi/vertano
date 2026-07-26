import Foundation

/// Live-transcription chunk sizing. Shorter chunks put text on screen sooner,
/// but are only viable with the resident server (fix A): the `whisper-cli`
/// fallback reloads the model per chunk, so smaller chunks there would just
/// multiply that cost. The fallback therefore keeps the long legacy chunk.
enum LiveChunking {
    static let defaultChunkSeconds = 5
    static let legacyChunkSeconds = 15

    static func sampleCount(seconds: Int, sampleRate: Int) -> Int {
        seconds * sampleRate
    }

    static func defaultChunkSampleCount(sampleRate: Int) -> Int {
        sampleCount(seconds: defaultChunkSeconds, sampleRate: sampleRate)
    }

    static func legacyChunkSampleCount(sampleRate: Int) -> Int {
        sampleCount(seconds: legacyChunkSeconds, sampleRate: sampleRate)
    }

    static func chunkSampleCount(residentServer: Bool, sampleRate: Int) -> Int {
        residentServer
            ? defaultChunkSampleCount(sampleRate: sampleRate)
            : legacyChunkSampleCount(sampleRate: sampleRate)
    }
}
