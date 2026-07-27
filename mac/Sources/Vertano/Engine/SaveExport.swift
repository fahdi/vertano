import Foundation

/// Suggested filename for saving a combined transcript export. When a search
/// is active the query is folded (sanitized) into the name so the saved file
/// is self-describing.
enum SaveExport {
    static func filename(query: String) -> String {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Vertano Transcripts.txt" }
        let term = TranscriptNaming.baseName(transcript: trimmed, fallback: "search")
        return "Vertano - \(term).txt"
    }
}
