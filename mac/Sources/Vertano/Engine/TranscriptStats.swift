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

    /// Estimated reading time at ~200 words per minute, rounded up. Zero words
    /// means no estimate.
    static let wordsPerMinute = 200

    static func readingTimeMinutes(wordCount: Int) -> Int {
        guard wordCount > 0 else { return 0 }
        return Int((Double(wordCount) / Double(wordsPerMinute)).rounded(.up))
    }

    static func readingTimeLabel(for text: String) -> String {
        let minutes = readingTimeMinutes(wordCount: wordCount(text))
        return minutes == 0 ? "" : "~\(minutes) min read"
    }

    /// Combined "N words · ~M min read" (reading time omitted when there are
    /// no words).
    static func detail(for text: String) -> String {
        let reading = readingTimeLabel(for: text)
        return reading.isEmpty ? label(for: text) : "\(label(for: text)) · \(reading)"
    }
}
