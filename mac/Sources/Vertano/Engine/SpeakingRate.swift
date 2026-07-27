import Foundation

/// Live speaking pace (words per minute) during a recording. Useful to
/// presenters, podcasters, and interviewers monitoring delivery. Returns nil
/// until there is enough audio for a stable number.
enum SpeakingRate {
    static let warmupSeconds = 3.0

    static func wordsPerMinute(words: Int, seconds: Double) -> Int? {
        guard seconds >= warmupSeconds else { return nil }
        return Int((Double(words) / (seconds / 60)).rounded())
    }

    static func label(words: Int, seconds: Double) -> String? {
        guard let wpm = wordsPerMinute(words: words, seconds: seconds) else { return nil }
        return "\(wpm) wpm"
    }
}
