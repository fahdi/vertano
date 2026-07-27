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
