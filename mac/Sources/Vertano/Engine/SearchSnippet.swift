import Foundation

/// A short, one-line excerpt of a transcript centered on the first match of a
/// search query, with ellipses where it was clipped — so a content search can
/// show *where* a term appears, like a search-engine result.
enum SearchSnippet {
    static func excerpt(text: String, query: String, radius: Int = 30) -> String? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
            let match = text.range(of: trimmed, options: .caseInsensitive)
        else { return nil }

        let lower =
            text.index(match.lowerBound, offsetBy: -radius, limitedBy: text.startIndex)
            ?? text.startIndex
        let upper =
            text.index(match.upperBound, offsetBy: radius, limitedBy: text.endIndex)
            ?? text.endIndex

        var snippet = String(text[lower..<upper]).replacingOccurrences(of: "\n", with: " ")
        if lower > text.startIndex { snippet = "…" + snippet }
        if upper < text.endIndex { snippet += "…" }
        return snippet
    }
}
