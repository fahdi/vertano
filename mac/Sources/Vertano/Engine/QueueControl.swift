import Foundation

/// Queue-control predicates. Pending work = anything queued or actively
/// processing (as opposed to finished), which gates the pause/resume affordance.
enum QueueControl {
    static func hasPendingWork(_ statuses: [JobStatus]) -> Bool {
        statuses.contains { $0 == .queued || $0.isActive }
    }
}
