import Foundation

/// Formats an elapsed-seconds count for the recording timer. Adds an hours
/// field past the hour mark so long-form recordings (lectures, meetings,
/// interviews) read correctly instead of overflowing the minutes field.
enum TimeDisplay {
    static func elapsed(_ seconds: Int) -> String {
        let total = max(0, seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }
}
