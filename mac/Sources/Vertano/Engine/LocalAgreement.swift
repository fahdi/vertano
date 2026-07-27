import Foundation

/// LocalAgreement-2 streaming commit rule (Macháček et al., 2023). Each new
/// hypothesis is a full transcription of the current audio buffer. A word is
/// *confirmed* only once two consecutive hypotheses agree on it, so the live
/// transcript never commits a word that the next decode might revise, and
/// words are never split at an arbitrary chunk boundary. The unconfirmed tail
/// is shown tentatively and allowed to change.
struct LocalAgreement {
    private(set) var confirmed: [String] = []
    private var previous: [String] = []

    /// Feed the latest full-buffer hypothesis; returns the words newly
    /// confirmed by this hypothesis (empty if nothing new agreed).
    mutating func insert(_ hypothesis: [String]) -> [String] {
        let agreed = Self.commonPrefix(previous, hypothesis)
        previous = hypothesis
        // Confirmed words are never revoked: only grow.
        guard agreed.count > confirmed.count else { return [] }
        let newly = Array(agreed[confirmed.count...])
        confirmed = agreed
        return newly
    }

    /// Words in the latest hypothesis beyond the confirmed prefix.
    var tentative: [String] {
        guard previous.count > confirmed.count else { return [] }
        return Array(previous[confirmed.count...])
    }

    var confirmedText: String { confirmed.joined(separator: " ") }

    static func commonPrefix(_ a: [String], _ b: [String]) -> [String] {
        var result: [String] = []
        for (x, y) in zip(a, b) {
            guard x == y else { break }
            result.append(x)
        }
        return result
    }
}
