# StenoDrop Mac — Translate Downloaded Caption Files (.srt/.vtt)

Date: 2026-07-17 · Status: Draft — planning only, not yet approved for implementation

## Why this exists

Users can already download a YouTube video's captions (via yt-dlp, browser
extensions, or YouTube Studio for their own videos) as a `.srt` or `.vtt`
file. There's no audio to run through whisper — the file already **is**
a transcript, just one with per-line timing. The ask: drop that file into
StenoDrop and get back translated caption files in one or more languages,
each still correctly timed, so they can be re-uploaded as subtitles.

This is a natural extension of the multi-language translation pipeline
shipped today (`TranslationBridge` / `TranslationPipeline` /
`targetLanguages`) — captions reuse that same engine and the same
persisted language selection, but skip whisper and audio entirely, and
must preserve per-cue timing through translation rather than working on
one flat block of text.

## The complication that shapes this design

YouTube's **auto-generated** captions (the common case — most people
grabbing captions want the free auto ones, not manually authored tracks)
are downloaded as **rolling captions**: each cue re-displays overlapping
words from the previous cue, mimicking the live-scrolling caption
animation. Translating and re-emitting cue-for-cue without fixing this
first produces subtitles with the same repeated-word artifact, just
translated. Manually-authored/creator-uploaded captions don't have this
problem. Decision: **v1 detects and reflows rolling captions** (see
below) rather than either ignoring the artifact or rejecting auto-caption
files outright — auto-captions are the primary use case this feature
exists for.

## Architecture

### 1. Parsing (`CaptionFile`, new)

A pure parser for both formats into a shared cue model:

```swift
struct Cue {
    let start: TimeInterval
    let end: TimeInterval
    let text: String
}
```

- `.srt`: numbered blocks, `HH:MM:SS,mmm --> HH:MM:SS,mmm` (comma millis).
- `.vtt`: `WEBVTT` header, `HH:MM:SS.mmm --> HH:MM:SS.mmm` (dot millis),
  optional cue identifiers and cue settings (`align:start position:0%`,
  stripped/ignored), inline tags (`<i>`, `<c>`, `<00:00:01.000>` timestamp
  tags) stripped to plain text.
- Both directions: whichever format was read in is the format written
  back out for translated files (an `.srt` in, `.srt` out per language;
  same for `.vtt`).

### 2. Rolling-caption reflow (pure function, the core new algorithm)

Given consecutive cues, detect when a cue's text is (mostly) the previous
cue's text plus new trailing words — the rolling-caption signature — and
collapse the run into clean, non-overlapping cues:

- Compare consecutive cues word-by-word; find the longest suffix-of-A /
  prefix-of-B overlap.
- Emit only the new trailing words for each cue, with contiguous timing
  (this cue's end becomes the next cue's start, no gaps/overlaps).
- Cues that become empty after de-overlapping are dropped and their time
  range folded into the neighboring cue.
- Non-rolling caption files (manually authored, no overlap detected) pass
  through unchanged — this is a no-op when there's nothing to reflow, so
  it's always safe to run rather than needing a separate "is this
  rolling?" detection gate.

This is a pure `[Cue] -> [Cue]` function — fully unit-testable without any
file I/O or framework dependency, same testing pattern as
`TranslationPipeline`.

### 3. Source language

No whisper step means no `-l` language flag to lean on. Source language
for translation is auto-detected from the reflowed cue text using
Apple's **NaturalLanguage** framework (`NLLanguageRecognizer` — on-device,
free, macOS 10.14+, no new OS requirement beyond what translation already
needs). No new language-picker UI for captions; auto-detect is the
default and matches the app's existing "just drop the file in" ergonomic.

### 4. Translation dispatch — different from the audio pipeline

The existing `TranslationPipeline` special-cases `"en"` to whisper's
native audio-level translate. **Captions have no audio**, so that
special case doesn't apply: every selected target language, including
English, routes through `TranslationEngine`. If the detected source
language already equals a selected target, that language is skipped
(copy through, don't pay for a no-op translation call).

Cue-by-cue serial translation (reusing today's one-request-at-a-time
`TranslationBridge` queue) would mean one round-trip per cue — potentially
hundreds for a full video. `TranslationSession` has a real batch API
(`translations(from: [Request]) async throws -> [Response]`, same macOS 15
availability as everything else here) that translates a whole list in one
session call. `TranslationEngine`/`TranslationBridge` gain a batch method
so a caption file's cues translate as one batch per target language
instead of N serial requests.

### 5. Job model & ingestion

`TranscriptionJob` is audio-shaped (`sourceURL`, ffmpeg/whisper fields) —
rather than overload it, a parallel `CaptionJob` model carries `sourceURL`,
`cues: [Cue]`, detected source language, and per-target-language output
paths. `JobQueue.ingest(urls:)` currently filters by `audioExtensions`;
it gains `.srt`/`.vtt` recognition that routes to a separate caption
pipeline (parse → reflow → detect language → batch-translate per selected
target → write `filename.<lang>.srt`/`.vtt`) instead of the
whisper/ffmpeg pipeline. Both job kinds share the same `targetLanguages`
setting and can likely share `JobRowView` with a kind indicator (icon or
label distinguishing "audio" from "captions").

### 6. Output

One timed subtitle file per selected target language, same format as the
input (`.srt` in → `.srt` out), named `filename.<lang>.srt`. The original
file is left untouched — no need to write back an unmodified copy of
what's already on disk. A flattened plain-text transcript (the cleaned,
reflowed cue text concatenated) is easy to add later since the reflow
step already produces it internally, but is out of scope for v1 to keep
this focused.

## Testing plan (TDD, same philosophy as the translation feature)

Pure and unit-testable: `.srt`/`.vtt` parsing (round-trip fixtures,
including malformed/edge-case files), the rolling-caption reflow
algorithm (rolling input → clean output fixtures; non-rolling input →
unchanged), output filename generation, and translation dispatch
(faked `TranslationEngine`, verifying batch calls happen once per target
language with the right cue texts, not per-cue). NOT covered by automated
tests, same as the existing translation feature: real
`NLLanguageRecognizer` detection accuracy and real `TranslationSession`
output — verified manually.

## Out of scope (v1)

- Flattened plain-text output alongside timed subtitles (easy follow-up).
- A manual source-language override UI (auto-detect only, for now).
- Formats other than `.srt`/`.vtt` (e.g. `.sbv`, `.ttml`, `.ass`).
- Fetching captions directly from a YouTube URL — this only handles
  files the user has already downloaded themselves, nothing fetches from
  YouTube on the app's behalf.
- Reflow quality tuning beyond the core algorithm — real auto-caption
  files vary in how aggressively they roll; may need iteration once
  tested against real downloaded files.

## Open question for review

The reflow algorithm's word-overlap heuristic will need tuning against
real downloaded auto-caption files (rolling behavior isn't perfectly
uniform across videos/languages) — worth budgeting a pass with a handful
of real `.vtt` downloads before considering this feature done, not just
synthetic test fixtures.
