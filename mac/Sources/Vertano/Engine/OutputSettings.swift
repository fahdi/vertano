import Foundation

/// User preferences for what gets written alongside a transcript. Subtitle
/// files (.srt/.vtt) are on by default; users who only want the transcript can
/// turn them off.
enum OutputSettings {
    static let subtitlesKey = "subtitlesEnabled"

    static func resolveSubtitlesEnabled(stored: Bool?) -> Bool { stored ?? true }

    static var subtitlesEnabled: Bool {
        resolveSubtitlesEnabled(stored: UserDefaults.standard.object(forKey: subtitlesKey) as? Bool)
    }

    static let flowParagraphsKey = "flowParagraphs"

    /// Off by default so existing line-per-segment output is unchanged.
    static func resolveFlowParagraphs(stored: Bool?) -> Bool { stored ?? false }

    static var flowParagraphs: Bool {
        resolveFlowParagraphs(
            stored: UserDefaults.standard.object(forKey: flowParagraphsKey) as? Bool)
    }
}
