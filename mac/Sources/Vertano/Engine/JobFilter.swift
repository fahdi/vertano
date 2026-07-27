import Foundation

/// Case-insensitive filename matching for the job queue's search box, so a
/// batch of hundreds of files (a year of voice memos) stays navigable. An
/// empty query matches everything.
enum JobFilter {
    static func matches(filename: String, query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        return filename.localizedCaseInsensitiveContains(trimmed)
    }
}
