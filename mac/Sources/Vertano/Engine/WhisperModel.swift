import Foundation

/// A single downloadable whisper.cpp model. This is the general catalog that
/// backs the "All models" list; `ModelTier` is the curated three-preset subset
/// layered on top for the "Recommended" section.
struct WhisperModel: Identifiable, Equatable, Sendable {
    let filename: String
    let displayName: String
    /// Approximate on-disk size, used for the size label and to derive the
    /// truncated-download floor.
    let approximateBytes: Int64
    /// True for multilingual models; false for `.en` English-only builds.
    let multilingual: Bool

    var id: String { filename }

    var downloadURL: URL {
        URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/\(filename)")!
    }

    var approximateSizeLabel: String {
        ByteCountFormatter.string(fromByteCount: approximateBytes, countStyle: .file)
    }

    /// Anything below half the expected size is a truncated download or an
    /// HTML error page.
    var minimumValidSize: Int64 { approximateBytes / 2 }

    static func named(_ filename: String) -> WhisperModel? {
        all.first { $0.filename == filename }
    }
}

extension WhisperModel {
    private static let mb: Int64 = 1_000_000

    /// Every model whisper.cpp publishes under `ggerganov/whisper.cpp`: the
    /// full size ladder, English-only (`.en`) builds, and quantized (`q5`)
    /// variants. Ordered smallest to largest for display.
    static let all: [WhisperModel] = [
        WhisperModel(filename: "ggml-tiny-q5_1.bin", displayName: "Tiny (compressed)", approximateBytes: 31 * mb, multilingual: true),
        WhisperModel(filename: "ggml-tiny.en-q5_1.bin", displayName: "Tiny · English (compressed)", approximateBytes: 31 * mb, multilingual: false),
        WhisperModel(filename: "ggml-tiny.bin", displayName: "Tiny", approximateBytes: 75 * mb, multilingual: true),
        WhisperModel(filename: "ggml-tiny.en.bin", displayName: "Tiny · English", approximateBytes: 75 * mb, multilingual: false),
        WhisperModel(filename: "ggml-base-q5_1.bin", displayName: "Base (compressed)", approximateBytes: 57 * mb, multilingual: true),
        WhisperModel(filename: "ggml-base.en-q5_1.bin", displayName: "Base · English (compressed)", approximateBytes: 57 * mb, multilingual: false),
        WhisperModel(filename: "ggml-base.bin", displayName: "Base", approximateBytes: 142 * mb, multilingual: true),
        WhisperModel(filename: "ggml-base.en.bin", displayName: "Base · English", approximateBytes: 142 * mb, multilingual: false),
        WhisperModel(filename: "ggml-small-q5_1.bin", displayName: "Small (compressed)", approximateBytes: 182 * mb, multilingual: true),
        WhisperModel(filename: "ggml-small.en-q5_1.bin", displayName: "Small · English (compressed)", approximateBytes: 182 * mb, multilingual: false),
        WhisperModel(filename: "ggml-small.bin", displayName: "Small", approximateBytes: 466 * mb, multilingual: true),
        WhisperModel(filename: "ggml-small.en.bin", displayName: "Small · English", approximateBytes: 466 * mb, multilingual: false),
        WhisperModel(filename: "ggml-medium-q5_0.bin", displayName: "Medium (compressed)", approximateBytes: 514 * mb, multilingual: true),
        WhisperModel(filename: "ggml-medium.en-q5_0.bin", displayName: "Medium · English (compressed)", approximateBytes: 514 * mb, multilingual: false),
        WhisperModel(filename: "ggml-medium.bin", displayName: "Medium", approximateBytes: 1_500 * mb, multilingual: true),
        WhisperModel(filename: "ggml-medium.en.bin", displayName: "Medium · English", approximateBytes: 1_500 * mb, multilingual: false),
        WhisperModel(filename: "ggml-large-v3-turbo-q5_0.bin", displayName: "Large v3 Turbo (compressed)", approximateBytes: 547 * mb, multilingual: true),
        WhisperModel(filename: "ggml-large-v2-q5_0.bin", displayName: "Large v2 (compressed)", approximateBytes: 1_100 * mb, multilingual: true),
        WhisperModel(filename: "ggml-large-v3-q5_0.bin", displayName: "Large v3 (compressed)", approximateBytes: 1_100 * mb, multilingual: true),
        WhisperModel(filename: "ggml-large-v3-turbo.bin", displayName: "Large v3 Turbo", approximateBytes: 1_600 * mb, multilingual: true),
        WhisperModel(filename: "ggml-large-v1.bin", displayName: "Large v1", approximateBytes: 2_900 * mb, multilingual: true),
        WhisperModel(filename: "ggml-large-v2.bin", displayName: "Large v2", approximateBytes: 2_900 * mb, multilingual: true),
        WhisperModel(filename: "ggml-large-v3.bin", displayName: "Large v3", approximateBytes: 3_100 * mb, multilingual: true),
    ]
}
