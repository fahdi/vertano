import Foundation

/// A batch-wide search summary — total term occurrences across how many files —
/// so a research query gives the big picture at a glance.
enum SearchSummary {
    static func summary(texts: [String], query: String) -> String? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        var totalMatches = 0
        var matchingFiles = 0
        for text in texts {
            let count = SearchSnippet.matchCount(text: text, query: trimmed)
            if count > 0 {
                matchingFiles += 1
                totalMatches += count
            }
        }
        guard totalMatches > 0 else { return nil }

        let matches = "\(totalMatches) \(totalMatches == 1 ? "match" : "matches")"
        let files = "\(matchingFiles) \(matchingFiles == 1 ? "file" : "files")"
        return "\(matches) in \(files)"
    }
}
