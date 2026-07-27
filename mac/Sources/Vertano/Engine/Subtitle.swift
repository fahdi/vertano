import Foundation

/// One subtitle cue: a time span (milliseconds) and its text.
struct SubtitleCue: Equatable {
    let startMs: Int
    let endMs: Int
    let text: String
}

/// SRT timecode formatting: `HH:MM:SS,mmm`.
enum SRTTimecode {
    static func format(milliseconds: Int) -> String {
        let ms = max(0, milliseconds)
        let h = ms / 3_600_000
        let m = (ms % 3_600_000) / 60_000
        let s = (ms % 60_000) / 1000
        let millis = ms % 1000
        return String(format: "%02d:%02d:%02d,%03d", h, m, s, millis)
    }
}

/// Parses whisper-cli `-oj` output into cues.
enum WhisperJSON {
    static func cues(_ data: Data) -> [SubtitleCue] {
        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let segments = object["transcription"] as? [[String: Any]]
        else { return [] }

        return segments.compactMap { segment in
            guard
                let offsets = segment["offsets"] as? [String: Any],
                let from = offsets["from"] as? Int,
                let to = offsets["to"] as? Int,
                let text = segment["text"] as? String
            else { return nil }
            return SubtitleCue(
                startMs: from, endMs: to,
                text: text.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }
}

/// Builds an SRT document from cues (blank text skipped, blocks renumbered).
enum SRTBuilder {
    static func build(_ cues: [SubtitleCue]) -> String {
        var blocks: [String] = []
        var index = 1
        for cue in cues {
            let text = cue.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            let timecode =
                "\(SRTTimecode.format(milliseconds: cue.startMs))"
                + " --> \(SRTTimecode.format(milliseconds: cue.endMs))"
            blocks.append("\(index)\n\(timecode)\n\(text)")
            index += 1
        }
        return blocks.joined(separator: "\n\n")
    }
}

/// WebVTT timecode: `HH:MM:SS.mmm` (dot, not comma).
enum VTTTimecode {
    static func format(milliseconds: Int) -> String {
        let ms = max(0, milliseconds)
        return String(
            format: "%02d:%02d:%02d.%03d",
            ms / 3_600_000, (ms % 3_600_000) / 60_000, (ms % 60_000) / 1000, ms % 1000)
    }
}

/// Builds a WebVTT document (the web/HTML5/YouTube caption format).
enum VTTBuilder {
    static func build(_ cues: [SubtitleCue]) -> String {
        let blocks = cues.compactMap { cue -> String? in
            let text = cue.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }
            return "\(VTTTimecode.format(milliseconds: cue.startMs))"
                + " --> \(VTTTimecode.format(milliseconds: cue.endMs))\n\(text)"
        }
        guard !blocks.isEmpty else { return "" }
        return "WEBVTT\n\n" + blocks.joined(separator: "\n\n")
    }
}

/// The subtitle siblings of a transcript output path.
enum SubtitleOutput {
    static func srtURL(for transcriptURL: URL) -> URL {
        transcriptURL.deletingPathExtension().appendingPathExtension("srt")
    }

    static func vttURL(for url: URL) -> URL {
        url.deletingPathExtension().appendingPathExtension("vtt")
    }
}
