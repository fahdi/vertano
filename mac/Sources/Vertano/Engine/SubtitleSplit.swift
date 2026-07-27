import Foundation

/// Splits over-long subtitle cues into readable caption-length pieces. Whisper
/// emits one cue per spoken segment, which can be a full sentence on screen at
/// once; this wraps the text at word boundaries and divides the time span
/// proportionally so each cue is a comfortable length.
enum SubtitleSplit {
    static func wrap(_ cues: [SubtitleCue], maxChars: Int) -> [SubtitleCue] {
        cues.flatMap { split($0, maxChars: maxChars) }
    }

    private static func split(_ cue: SubtitleCue, maxChars: Int) -> [SubtitleCue] {
        guard cue.text.count > maxChars else { return [cue] }
        let pieces = wrapWords(cue.text, maxChars: maxChars)
        let totalChars = max(pieces.reduce(0) { $0 + $1.count }, 1)
        let span = cue.endMs - cue.startMs

        var result: [SubtitleCue] = []
        var start = cue.startMs
        for (index, piece) in pieces.enumerated() {
            let end =
                index == pieces.count - 1
                ? cue.endMs
                : start + span * piece.count / totalChars
            result.append(SubtitleCue(startMs: start, endMs: end, text: piece))
            start = end
        }
        return result
    }

    static func wrapWords(_ text: String, maxChars: Int) -> [String] {
        var lines: [String] = []
        var current = ""
        for word in text.split(separator: " ").map(String.init) {
            if current.isEmpty {
                current = word
            } else if current.count + 1 + word.count <= maxChars {
                current += " " + word
            } else {
                lines.append(current)
                current = word
            }
        }
        if !current.isEmpty { lines.append(current) }
        return lines.isEmpty ? [text] : lines
    }
}
