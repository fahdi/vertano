import Foundation

/// Command-line flags shared by the resident `whisper-server` launch and the
/// `whisper-cli` fallback. Verified against the installed whisper.cpp build:
/// GPU (Metal) is on by default, so speed comes from *not* disabling it, from
/// enabling flash attention, and from greedy low-latency decoding.
struct WhisperFlags {
    /// Metal flash-attention kernel; a large speedup on Apple Silicon.
    var flashAttention = true
    /// GPU is on by default in whisper.cpp; disabling emits `-ng`.
    var useGPU = true
    /// Decode threads. Defaults to the machine's cores, clamped.
    var threads: Int = WhisperFlags.defaultThreads
    /// Beam size 1 == greedy: fastest per chunk.
    var beamSize = 1
    var bestOf = 1
    /// Skip temperature fallback retries; they multiply latency.
    var noFallback = true
    /// Voice Activity Detection: segment on real speech and drop silence,
    /// which removes Whisper's silence-hallucination failure at chunk edges.
    var vad = true
    /// Below this no-speech probability a segment is treated as silence.
    var noSpeechThreshold = 0.6
    /// Suppress non-speech tokens (music/noise markers) in the output.
    var suppressNonSpeech = true
    /// Prior confirmed words fed back as context so terminology, casing, and
    /// punctuation stay coherent across buffer trims. Nil/empty omits it.
    var initialPrompt: String?

    func arguments() -> [String] {
        var args: [String] = []
        if flashAttention { args.append("-fa") }
        if !useGPU { args.append("-ng") }
        args += ["-t", String(WhisperFlags.clampThreads(threads))]
        args += ["-bs", String(beamSize)]
        args += ["-bo", String(bestOf)]
        if noFallback { args.append("-nf") }
        if vad { args.append("--vad") }
        args += ["-nth", String(noSpeechThreshold)]
        if suppressNonSpeech { args.append("-sns") }
        if let initialPrompt, !initialPrompt.isEmpty {
            args += ["--prompt", initialPrompt]
        }
        return args
    }

    /// File-transcription profile: accuracy over latency (real beam search,
    /// temperature fallback on) but still fast — all cores, flash attention,
    /// non-speech tokens suppressed. Whisper-cli otherwise defaults to only 4
    /// threads, leaving most of the machine idle on a batch.
    static var batch: WhisperFlags {
        var flags = WhisperFlags()
        flags.beamSize = 5
        flags.bestOf = 5
        flags.noFallback = false
        flags.vad = false
        return flags
    }

    static let maxThreads = 16

    static func clampThreads(_ requested: Int) -> Int {
        min(max(requested, 1), maxThreads)
    }

    static var defaultThreads: Int {
        clampThreads(ProcessInfo.processInfo.activeProcessorCount)
    }
}
