import Foundation

/// Transcript metrics surfaced to the user. Word count is the metric the
/// writing/research audience (journalists, students, researchers) expects from
/// a transcription tool, so it appears live while recording.
enum TranscriptStats {
    static func wordCount(_ text: String) -> Int {
        text.split(whereSeparator: \.isWhitespace).count
    }

    static func label(for text: String) -> String {
        let count = wordCount(text)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.groupingSeparator = ","
        let number = formatter.string(from: NSNumber(value: count)) ?? "\(count)"
        return "\(number) \(count == 1 ? "word" : "words")"
    }
}
