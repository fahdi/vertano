import Foundation

/// Whether a job may be removed from the queue. A job that is actively being
/// processed must stay: its running task holds an index into the queue and
/// pumps the next job on completion, so removing it mid-flight would corrupt
/// the pipeline.
enum JobRemoval {
    static func canRemove(_ status: JobStatus) -> Bool {
        !status.isActive
    }
}
