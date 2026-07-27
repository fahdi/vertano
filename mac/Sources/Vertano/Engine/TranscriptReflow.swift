import Foundation

/// Reflows a segment-broken transcript into flowing paragraphs: single line
/// breaks (one per Whisper segment, often mid-sentence) become spaces, while
/// blank lines are kept as paragraph breaks. Opt-in — the default keeps the
/// line-per-segment output.
enum TranscriptReflow {
    static func flow(_ text: String) -> String {
        var paragraphs: [String] = []
        var current: [String] = []
        for line in text.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                if !current.isEmpty {
                    paragraphs.append(current.joined(separator: " "))
                    current = []
                }
            } else {
                current.append(trimmed)
            }
        }
        if !current.isEmpty { paragraphs.append(current.joined(separator: " ")) }
        return paragraphs.joined(separator: "\n\n")
    }
}
