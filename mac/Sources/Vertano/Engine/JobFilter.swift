import Foundation

/// Case-insensitive filename matching for the job queue's search box, so a
/// batch of hundreds of files (a year of voice memos) stays navigable. An
/// empty query matches everything.
enum JobFilter {
    static func matches(filename: String, query: String) -> Bool {
        matches(filename: filename, transcript: "", query: query)
    }

    /// Full-text: matches when the query appears in the file name or the
    /// transcript, so a search finds the file that *mentions* a term, not just
    /// the one named after it.
    static func matches(filename: String, transcript: String, query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        return filename.localizedCaseInsensitiveContains(trimmed)
            || transcript.localizedCaseInsensitiveContains(trimmed)
    }
}
