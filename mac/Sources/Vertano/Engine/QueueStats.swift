import Foundation

/// A compact progress readout for the job queue, so a long batch shows its
/// state at a glance ("5 of 12 done, 1 failed") instead of making the user
/// scan every row.
enum QueueStats {
    static func summary(statuses: [JobStatus]) -> String? {
        guard !statuses.isEmpty else { return nil }
        var done = 0
        var failed = 0
        for status in statuses {
            switch status {
            case .done, .doneWithWarning: done += 1
            case .failed: failed += 1
            case .queued, .converting, .transcribing, .translating: break
            }
        }
        var summary = "\(done) of \(statuses.count) done"
        if failed > 0 { summary += ", \(failed) failed" }
        return summary
    }

    /// Combined word count across the given transcripts — a corpus-size metric
    /// for the batch (useful to researchers and writers).
    static func totalWords(transcripts: [String]) -> Int {
        transcripts.reduce(0) { $0 + TranscriptStats.wordCount($1) }
    }

    static func totalWordsLabel(transcripts: [String]) -> String? {
        let total = totalWords(transcripts: transcripts)
        return total == 0 ? nil : "\(TranscriptStats.grouped(total)) words"
    }
}
