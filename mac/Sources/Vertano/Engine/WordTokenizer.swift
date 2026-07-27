import Foundation

/// Splits a transcript hypothesis into comparable word tokens for
/// LocalAgreement. Whitespace-delimited; the raw words (with punctuation)
/// are kept so the committed text reads naturally.
enum WordTokenizer {
    static func words(_ text: String) -> [String] {
        text.split(whereSeparator: \.isWhitespace).map(String.init)
    }
}
