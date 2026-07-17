# StenoDrop (Mac App)

Native macOS app for batch audio transcription and caption translation. Drag in
files or folders: audio/video gets transcribed locally, and downloaded caption
files (`.srt`/`.vtt`) get cleaned and translated into timed caption tracks —
offline, free, no API keys. Transcripts are saved as `.txt` next to each source
file and are also viewable/copyable in the app.

- **Engine:** `whisper-cli` (Homebrew `whisper-cpp`, Metal-accelerated). Three
  model tiers, switchable in Settings — Efficient (fast, single-language),
  Enhanced (better with accents/noise), Maximum (built for multilingual and
  Indic-language audio, including code-switching). Only Efficient downloads
  automatically on first launch; the others are opt-in.
- **Translate To** menu (multi-select, persists across launches). The original
  spoken-language transcript is always saved; each checked language adds its
  own translated output file. English uses whisper's native translate task;
  other languages use Apple's on-device Translation framework (macOS 15+,
  fully offline once the language pack is installed).
- **Language picker** (default Auto-detect). Force the spoken language when
  auto-detection misfires on short clips — e.g. Urdu heard as Hindi. Persists
  across launches.
- **Inputs:** wav, mp3, m4a, aac, flac, ogg/oga, opus, aiff, caf, amr, wma — plus
  video containers (mp4, mov, m4v, webm, mkv), from which the audio track is used.
  Everything is normalized to 16 kHz mono WAV via ffmpeg before transcription.
  **Caption files** (`.srt`, `.vtt`) are also accepted — no audio involved.
- Folders are scanned recursively; unsupported files are skipped. Jobs run
  sequentially; a failed file is marked with its error and the queue continues.

## Caption files (.srt / .vtt)

Drop a downloaded caption file (e.g. from `yt-dlp`, a browser extension, or
YouTube Studio) and StenoDrop:

- **Cleans it.** YouTube auto-generated captions download as "rolling"
  captions where every line appears twice; StenoDrop detects that structure
  and produces a deduplicated, correctly retimed track. Manually authored and
  karaoke-style files pass through untouched.
- **Always saves the cleaned source track** as `name.<lang>.srt`/`.vtt` plus a
  flattened `name.<lang>.txt` — the original file is never modified.
- **Translates it** into every language checked under Translate To, one timed
  caption file per language, using Apple's on-device Translation framework
  (macOS 15+, language packs download on first use).
- Picks the source language from the VTT `Language:` header, then the toolbar
  Language picker (when not Auto-detect), then on-device detection.
- If a caption file and its media file are dropped together (`Talk.mp4` +
  `Talk.en.vtt`), the caption file wins and the media file is skipped.

**Known limitations:**

- Apple Translation does not support Urdu, Bengali, Persian, Punjabi, or
  Pashto (in either direction). Those languages are skipped with a note; the
  cleaned, deduplicated source track is still produced.
- The app bundle declares no `CFBundleDocumentTypes`, so Finder "Open With"
  and Dock-icon drops of `.srt`/`.vtt` files don't work — use the in-app drop
  zone or the file picker.

Requires macOS 15+.

## Record live

Click **Record** in the toolbar to capture from the microphone with a live
transcript that updates roughly every 15 seconds (using the current language
and translate settings). Stopping saves the full recording plus its transcript
to `~/Documents/StenoDrop/` as `Recording <date> at <time>.wav` and `.txt`.
First use prompts for microphone access — everything stays on your Mac.

## Prerequisites

```bash
brew install whisper-cpp ffmpeg
```

Whisper models are not bundled. On first launch the app shows a setup screen
that checks for both tools and offers a one-click download of the Efficient
model (to `~/Library/Application Support/StenoDrop/models/ggml-small.bin`).
Enhanced and Maximum are downloaded on demand from Settings → Model.

## Development

Plain Swift Package — no `.xcodeproj`.

```bash
cd mac
swift build
swift run
```

## Build the app bundle

```bash
cd mac
./scripts/make-app.sh
```

This builds a release binary, wraps it as `dist/StenoDrop.app`, and ad-hoc
signs it for local use (no notarization). Install it with:

```bash
cp -R dist/StenoDrop.app /Applications/
```

## Notes

- Output `.txt` goes next to the source file. If that location isn't writable
  (e.g. a read-only volume), the job is marked "Done (not saved)" and the
  transcript is still available in the app for copying.
- `whisper-cli` is located via `/opt/homebrew/bin`, `/usr/local/bin`, then `PATH`.
- Design specs: [`docs/superpowers/specs/2026-07-13-mac-app-design.md`](../docs/superpowers/specs/2026-07-13-mac-app-design.md), [`docs/superpowers/specs/2026-07-17-mac-model-tiers-translation-design.md`](../docs/superpowers/specs/2026-07-17-mac-model-tiers-translation-design.md)
