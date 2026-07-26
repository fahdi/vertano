import Foundation

/// Command-line flags shared by the resident `whisper-server` launch and the
/// `whisper-cli` fallback. Verified against the installed whisper.cpp build:
/// GPU (Metal) is on by default, so speed comes from *not* disabling it and
/// from enabling flash attention.
struct WhisperFlags {
    /// Metal flash-attention kernel; a large speedup on Apple Silicon.
    var flashAttention = true
    /// GPU is on by default in whisper.cpp; disabling emits `-ng`.
    var useGPU = true

    func arguments() -> [String] {
        var args: [String] = []
        if flashAttention { args.append("-fa") }
        if !useGPU { args.append("-ng") }
        return args
    }
}
