import Foundation

/// Removes Whisper's runaway word-repetition hallucination (the same word
/// echoed many times over silence or noise), which is more common on smaller
/// models. Deliberately conservative: it only activates when a word repeats
/// past `trigger` consecutive times, and when nothing triggers it returns the
/// input unchanged so normal transcripts keep their exact formatting.
enum TranscriptCleanup {
    static func collapseWordRuns(_ text: String, trigger: Int = 5, cap: Int = 3) -> String {
        let tokens = text.split(whereSeparator: \.isWhitespace).map(String.init)
        guard hasRun(tokens, longerThan: trigger) else { return text }

        var out: [String] = []
        var runWord: String?
        var runLength = 0
        for token in tokens {
            if token == runWord {
                runLength += 1
            } else {
                runWord = token
                runLength = 1
            }
            if runLength <= cap { out.append(token) }
        }
        return out.joined(separator: " ")
    }

    /// Whisper's standalone non-speech annotations for actual audio *events*.
    /// Deliberately excludes content markers like `[inaudible]`/`[unclear]`,
    /// which carry meaning worth keeping.
    private static let nonSpeechEvents = [
        "BLANK_AUDIO", "BLANK AUDIO", "MUSIC", "MUSIC PLAYING", "APPLAUSE",
        "LAUGHTER", "LAUGHING", "CHEERING", "SILENCE", "NOISE",
    ]

    /// Removes standalone `[...]`/`(...)` non-speech markers. Returns the input
    /// unchanged when none are present, so formatting is preserved.
    static func stripNonSpeechMarkers(_ text: String) -> String {
        let alternatives = nonSpeechEvents
            .map { NSRegularExpression.escapedPattern(for: $0) }
            .joined(separator: "|")
        let pattern = "[\\[(]\\s*(?:\(alternatives))\\s*[\\])]"
        guard
            let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        else { return text }

        let full = NSRange(text.startIndex..., in: text)
        guard regex.firstMatch(in: text, options: [], range: full) != nil else { return text }

        var result = regex.stringByReplacingMatches(in: text, range: full, withTemplate: "")
        // Tidy only the gaps the removals left behind.
        result = result.replacingOccurrences(
            of: "[ \\t]{2,}", with: " ", options: .regularExpression)
        result = result.replacingOccurrences(
            of: " *\\n *", with: "\n", options: .regularExpression)
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func hasRun(_ tokens: [String], longerThan limit: Int) -> Bool {
        var runWord: String?
        var runLength = 0
        for token in tokens {
            if token == runWord {
                runLength += 1
            } else {
                runWord = token
                runLength = 1
            }
            if runLength > limit { return true }
        }
        return false
    }
}
