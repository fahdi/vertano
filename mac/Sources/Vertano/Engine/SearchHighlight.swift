import Foundation

/// Locates every (non-overlapping, case-insensitive) occurrence of a query in
/// a transcript, so the expanded view can highlight matches in place.
enum SearchHighlight {
    static func matchRanges(in text: String, query: String) -> [NSRange] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let ns = text as NSString
        var ranges: [NSRange] = []
        var start = 0
        while start < ns.length {
            let found = ns.range(
                of: trimmed, options: .caseInsensitive,
                range: NSRange(location: start, length: ns.length - start))
            guard found.location != NSNotFound else { break }
            ranges.append(found)
            start = found.location + max(found.length, 1)
        }
        return ranges
    }
}
