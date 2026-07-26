import Foundation

/// The lightweight model that drives the live scrolling transcript. It trades
/// accuracy for speed so text appears with minimal latency; the saved artifact
/// is re-transcribed at the user's chosen `ModelTier` (see
/// `WhisperEngine.finalTranscriptionTier`).
enum LiveModel {
    static let instantFilename = "ggml-base.bin"
    static let instantURL = URL(
        string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin")!
    /// Below this a download is truncated or an error page (ggml-base is ~150 MB).
    static let instantMinimumValidSize: Int64 = 100_000_000
}

/// Which model the live path should feed to whisper for a given chunk.
enum LiveModelChoice: Equatable {
    case instant
    case accurate(ModelTier)

    var filename: String {
        switch self {
        case .instant: LiveModel.instantFilename
        case .accurate(let tier): tier.filename
        }
    }
}
