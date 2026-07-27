import Foundation

/// Concatenates a batch of transcripts into one document (filename header +
/// text per file), so a whole project can be copied out in a single action.
/// Files with no transcript are skipped.
enum BatchExport {
    static func combined(
        _ items: [(filename: String, transcript: String)], header: String? = nil
    ) -> String {
        let body = items
            .filter { !$0.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map { "\($0.filename)\n\n\($0.transcript)" }
            .joined(separator: "\n\n")
        guard !body.isEmpty else { return "" }
        if let header, !header.isEmpty { return "\(header)\n\n\(body)" }
        return body
    }
}
