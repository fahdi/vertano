import Foundation

/// Requeue logic for failed jobs, so a transient failure (a locked file, a
/// momentary resource hiccup) can be retried without re-adding the file.
enum RetryPlan {
    /// A failed job becomes queued again; any other state is left as-is.
    static func reset(_ status: JobStatus) -> JobStatus {
        if case .failed = status { return .queued }
        return status
    }

    static func retriableCount(_ statuses: [JobStatus]) -> Int {
        statuses.reduce(0) { count, status in
            if case .failed = status { return count + 1 }
            return count
        }
    }
}
