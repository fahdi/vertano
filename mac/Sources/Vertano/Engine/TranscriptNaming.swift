import Foundation

/// Derives a human-friendly filename from a transcript's opening words, so a
/// folder of recordings is browsable by content ("Meeting Q3 budget review")
/// instead of by opaque timestamps. Falls back to the timestamp name when the
/// transcript is empty (e.g. a silent recording).
enum TranscriptNaming {
    static let maxLength = 48

    private static let illegal = CharacterSet(charactersIn: "/\\:*?\"<>|\n\r\t")

    static func baseName(transcript: String, fallback: String) -> String {
        let words = transcript
            .components(separatedBy: illegal)
            .joined(separator: " ")
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
        guard !words.isEmpty else { return fallback }

        var result = ""
        for word in words {
            let candidate = result.isEmpty ? word : result + " " + word
            if candidate.count > maxLength {
                // A single leading word longer than the limit: hard-truncate it
                // so we still produce a content-based name.
                if result.isEmpty { result = String(word.prefix(maxLength)) }
                break
            }
            result = candidate
        }
        return result.isEmpty ? fallback : result
    }
}
