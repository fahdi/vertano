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

    func arguments() -> [String] {
        var args: [String] = []
        if flashAttention { args.append("-fa") }
        if !useGPU { args.append("-ng") }
        args += ["-t", String(WhisperFlags.clampThreads(threads))]
        args += ["-bs", String(beamSize)]
        args += ["-bo", String(bestOf)]
        if noFallback { args.append("-nf") }
        return args
    }

    static let maxThreads = 16

    static func clampThreads(_ requested: Int) -> Int {
        min(max(requested, 1), maxThreads)
    }

    static var defaultThreads: Int {
        clampThreads(ProcessInfo.processInfo.activeProcessorCount)
    }
}
