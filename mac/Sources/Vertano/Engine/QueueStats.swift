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
}
