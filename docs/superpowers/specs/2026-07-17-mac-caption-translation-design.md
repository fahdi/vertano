# StenoDrop Mac — Translate Downloaded Caption Files (.srt/.vtt)

Date: 2026-07-17 · Status: Revised after adversarial review round 1 (33
findings, 11 accepted revisions). Supersedes the same-day draft in place.

## Why this exists

Users can already download a YouTube video's captions (via yt-dlp, browser
extensions, or YouTube Studio for their own videos) as a `.srt` or `.vtt`
file. There's no audio to run through whisper — the file already **is** a
transcript with per-line timing. The ask: drop that file into StenoDrop
and get back cleaned and translated caption files, still correctly timed,
usable for re-upload as subtitles.

Two things make this non-trivial, and both were mis-modeled in the first
draft of this spec (caught by adversarial review):

1. YouTube **auto-generated** captions download as "rolling" captions with
   a specific, structurally marked duplication format (documented below) —
   not the fuzzy word-overlap the draft assumed.
2. Apple's Translation framework — the app's on-device translation engine —
   **does not support Urdu, Bengali, Persian, Punjabi, or Pashto** in any
   direction. The flagship "Urdu captions → English" scenario cannot be
   served by translation in v1. The feature stays valuable for those
   languages because the cleaned, deduplicated source-language track is
   itself the primary output (see Output).

## The real input format (ground truth, verified against real files)

A yt-dlp-downloaded auto-caption `.vtt` is a strict alternation of:

- a **building cue** (a few seconds long) whose payload is TWO lines:
  line 1 is the *previous* completed line repeated verbatim as plain
  text; line 2 is the *new* line, carrying inline timestamp/`<c>` tags,
  e.g. `we<00:00:00.960><c> shall</c><00:00:01.500><c> fight</c>`;
- a **static cue** (~10 ms) holding just the completed plain line,
  sometimes with a filler line that is `&nbsp;` or a single space.

Key properties: duplication is whole-line and verbatim; the new content
is the only line containing inline timestamp tags; tags can split
mid-word (`TH<c>E </c><c>SE</c><c>RG</c>…` for `THE SERGEANT`).
Manually-authored caption files have none of this structure. SRT files
produced by `yt-dlp --convert-subs srt` have tags stripped but **keep**
the whole-line duplication.

## Architecture

### 1. Parsing (`CaptionFile`, new — pure, no I/O in the core)

Shared cue model, designed so reflow still has the structural signal:

```swift
struct CueLine {
    let text: String          // tag-free text (see tag stripping below)
    let hadInlineTimestamps: Bool
}
struct Cue {
    let startMs: Int          // integer milliseconds — never Double
    let endMs: Int
    let lines: [CueLine]
}
```

- **Timestamps**: SRT `HH:MM:SS,mmm` (comma); VTT `(HH:)?MM:SS.mmm` (dot,
  hours OPTIONAL, tolerate >2-digit hours). Stored as integer ms. Parsing
  and re-serialization round-trip exactly (test: timestamp string →
  ms → string is identity). Rounding, never truncation, anywhere a
  conversion happens.
- **Byte/line level**: strip a leading U+FEFF BOM; normalize `\r\n` and
  bare `\r` to `\n` before block splitting; EOF is an implicit block
  terminator (missing trailing newline is fine). Output convention:
  UTF-8, no BOM, `\n` line endings.
- **VTT grammar**: the `WEBVTT` header is a *block* — yt-dlp emits
  `WEBVTT\nKind: captions\nLanguage: en` — consume everything to the
  first blank line, tolerate `WEBVTT <text>`. The `Language:` header
  value is captured and surfaced (used for source-language priority).
  Skip `NOTE`, `STYLE`, and `REGION` blocks. Cue identifiers and cue
  settings (`align:`, `position:`, `line:`) are parsed past and dropped.
- **Inline tag stripping**: pure deletion of tag spans with
  byte-for-byte concatenation of surrounding text — no separator
  insertion, no trimming inside the line (tags split mid-word; joining
  with spaces garbles every cue). Fixture required using a real
  character-chunked sample.
- **Entities**: decode character references on parse (`&amp;` `&lt;`
  `&gt;` `&nbsp;` `&lrm;` `&rlm;` and numeric forms). Re-escape `&` and
  `<` when serializing VTT (SRT needs none).
- **Emptiness predicate** (feeds the reflow drop rule): empty after
  entity decoding and trimming Unicode whitespace *including* U+00A0 and
  zero-width (Cf) characters. Explicit in tests — not delegated to
  "trim".
- **What is intentionally dropped** (enumerated, not hand-waved):
  styling tags (`<i>`, `<b>`, `<c.class>`), cue settings/positioning,
  cue identifiers, word-level timestamps, ruby. `<v Speaker>` is
  content: preserved as a `Speaker: ` text prefix. Output is
  structure-preserving plain text — "same container format in, same out"
  (`.srt` → `.srt`, `.vtt` → `.vtt`), not a styling-faithful copy.
- **SRT indices**: ignored on parse (timestamps are the identity; real
  files have gaps and duplicates), always regenerated `1..N` on write.

### 2. Rolling-caption reflow (pure `[Cue] -> [Cue]`, deterministic)

No fuzzy matching exists anywhere in v1. Two structural paths:

- **VTT path** (tags present): keep only lines with
  `hadInlineTimestamps == true` (the new content); drop cues containing
  no timestamped line (the ~10 ms static duplicates). That's the whole
  algorithm — the format marks new content for us.
- **SRT path** (tags stripped by conversion, duplication retained):
  exact whole-line dedup — drop a block's first line when it equals the
  previous block's last emitted line; drop blocks contributing no new
  line, folding their duration into the **previous** cue (fold direction
  is normative) and only when contiguous; otherwise the range is simply
  discarded. Gated by a rolling-run detector: the dedup only applies
  within runs of ≥3 consecutive line-shift pairs with near-contiguous
  timing. Clean files with genuine repeats ("We will rock you" ×2,
  `[Applause]`, echoed answers) pass through byte-identical.

**Timing rules**: within a rolling run, a completed line spans from its
building cue's start to the next building cue's start *only when
adjacent with no gap*. A gap above ~1 s, or absence of the rolling
structure, ends the run: the cue keeps its own end. Inter-run gaps
(silence, music, scene breaks) are **preserved** — no global
"end = next start" rule (it would pin the last caption across minutes of
silence). Timing outside detected runs is untouched. After any rewrite,
`endMs` is clamped ≥ `startMs`. Cues are sorted by start before reflow;
time-overlapping cue pairs (simultaneous speakers — legal VTT) are
excluded from dedup entirely.

### 3. Source language — explicit, prioritized, plumbed end-to-end

Priority order:
1. The VTT `Language:` header when present (ground truth from YouTube).
2. The existing toolbar Language picker when not "auto" (the codebase's
   own comment says auto-detect misfires on exactly this user's content —
   Urdu heard as Hindi; romanized Urdu fools NLLanguageRecognizer too.
   The override UI already exists; a manual override is therefore NOT
   out of scope — it is the existing picker).
3. `NLLanguageRecognizer` on the reflowed text as fallback. Runs inside
   `Task.detached` with the recognizer created locally (it is not
   Sendable; `JobQueue` is `@MainActor`).

Language comparison is by `Locale.Language` components, never raw string
equality — NLLanguageRecognizer returns `zh-Hans`/`zh-Hant` while the
picker stores `zh`; a string compare silently breaks the skip rule for
Chinese. The mapping table is part of the implementation. If detection
returns nil or an out-of-list language: proceed, pass what we have, let
the session decide. The detected/used source language is **displayed in
the job row** so misdetection is visible before anyone re-uploads a
broken track.

### 4. Availability gate + honest scoping (the Urdu problem)

Verified empirically: Apple Translation's supported set is ~25 languages
(ar, da, de, en, es, fr, hi, id, it, ja, ko, nb, nl, pl, pt, ru, sv, th,
tr, uk, vi, zh variants). **ur, bn, fa, pa, ps — all in
`JobQueue.languages` — are unsupported as source or target.**

- Pre-flight: after source resolution, call
  `LanguageAvailability.status(from:to:)` for each selected target and
  fail that language fast with a per-language, user-facing message
  ("Apple Translation doesn't support Urdu") — surfaced via the job's
  warnings, before any translate call. Unsupported languages never
  reach a session.
- The cleaned source-language track is still always produced (Output,
  below), so the feature retains its core value for Urdu users: dedup.
- v1 accepts the limitation; a non-Apple engine for unsupported
  languages is a recorded follow-up, not silent scope creep.
- Related, pre-existing: the audio pipeline's translate menu has the
  same exposure for ur/bn/fa/pa/ps targets (audio → en is safe via
  whisper). Filed as its own issue; not fixed by this feature.

### 5. Translation unit — sentence grouping, not per-cue fragments

`translations(from:)` translates each Request independently: batching
fixes round-trip count, not context. Reflowed rolling cues are 3-8 word
mid-sentence fragments; fragment-wise MT yields word salad, and SOV/SVO
reordering (hi, ja, ko, tr are all in the picker) breaks cue-text ↔
cue-timing correspondence anyway. Therefore:

- Group reflowed cues into sentence-ish chunks (punctuation and
  pause-gap boundaries — reflow already yields contiguous text).
- Translate chunks via the batch API, one batch per target language.
- Redistribute translated chunk text back across the original cue
  timings proportionally by character count.

This is a deliberate v1 decision made with the quality evidence in
front of it — not an implementation detail to discover mid-build.

### 6. TranslationBridge redesign (not "gains a batch method")

The current bridge cannot carry this feature as-is. Known failure: the
`.translationTask` closure only re-fires when the Configuration *value*
changes; two consecutive same-target requests never trigger the second
closure — the continuation leaks and the job wedges forever (today's
audio path survives only because whisper's seconds-long gaps drain the
queue to nil between requests). Required changes:

1. **Guaranteed configuration transition per request**: keep the stored
   `Configuration` and call `invalidate()` (version bump) for each new
   head of queue, or an ordering-safe nil-between-heads scheme.
2. **Ordering-safe publish**: replace the fire-and-forget
   `Task { @MainActor … }` publish with a mechanism that cannot reorder
   (e.g. an `AsyncStream` consumed by a single main-actor task).
3. **Batch-typed queue**: `PendingRequest` becomes batch-capable
   (`texts: [String]`, explicit `sourceLanguage: Locale.Language?`,
   `target: Locale.Language`); `TranslationEngine` gains
   `translateBatch(_ texts: [String], from: Locale.Language?, to:
   Locale.Language) async throws -> [String]` — protocol, fakes, and
   the view closure all change shape.
4. **clientIdentifier correlation**: responses matched to inputs by
   `clientIdentifier` (chunk index), never array position. A fake-engine
   test returns responses out of order and must still pass.
5. `Configuration(source:target:)` carries the explicit source from §3 —
   today's hardcoded `source: nil` goes away.
6. Manual verification checklist gains: "two consecutive requests with
   the same target language", and "first-ever translation to a language
   triggers an in-session pack download — first batch is slow; per-
   language failure (pack missing) must not fail the whole job".

### 7. Job model — unified, not parallel

Everything keys off the single `jobs: [TranscriptionJob]` array: the
quit guard (`hasActiveWork`), ingest dedupe, the empty-state drop zone,
`clearFinished`/`hasFinishedJobs`, and the one `ForEach`. A parallel
caption-job array silently breaks all five. Therefore: one heterogeneous
collection — `enum Job { case audio(TranscriptionJob); case
captions(CaptionJob) }` (or a shared protocol), processed by the
existing single-flight `pump()` loop, which also serializes bridge
access. All five call sites are in scope and enumerated in the
implementation issue.

`JobStatus` gains `.translating` (a minutes-long caption batch is not
"Transcribing"), ideally with per-language progress ("Translating to
French (2 of 3)"). The caption row: expanded view shows the reflowed cue
text; "Reveal in Finder" generalizes to the output directory;
per-language failures reuse `doneWithWarning` like the audio pipeline.

### 8. Ingest & output naming — both filter sites, no silent overwrites

- Both filter sites change: the single-file branch in `ingest(urls:)`
  AND the directory enumerator `audioFiles(in:)` — otherwise folder
  drops of caption files match nothing while single-file drops work.
  Copy sweep: the "No supported audio files in that drop." notice, the
  drop-zone copy, the NSOpenPanel prompt/message, the translate-menu
  help text.
- **Naming collision, concrete**: yt-dlp already writes
  `<name>.<lang>.<ext>` — byte-identical to our output pattern.
  Translating `Talk.en.vtt` with Urdu selected must not clobber a
  user-downloaded `Talk.ur.vtt`. Rules: strip a recognized trailing ISO
  language code from the input basename before appending the target
  (`Talk.en.vtt` + ur → `Talk.ur.vtt` is fine *if free*); assign all
  per-language output paths at enqueue time; check them against other
  queued jobs' sources, other jobs' outputs, and pre-existing files on
  disk — never silently overwrite a file the app didn't create; fall
  back to the existing `appendingPathExtension` disambiguation pattern.
- **Mixed folders**: a yt-dlp folder holds `Talk.mp4` + `Talk.en.vtt`
  side by side; naïve ingest queues both and surprise-starts an
  hours-long whisper job. v1 rule: when a caption file shares a
  basename with a media file in the same drop, queue the caption file
  and skip the media file, noting it in the drop notice. (No cancel
  button exists app-wide; that stays a backlog item.)

### 9. Output

- **Always** emit the reflowed source-language file
  (`name.<sourceLang>.srt`/`.vtt`) as the primary output — analogous to
  the audio pipeline always writing `filename.txt`. The reflowed cues
  are *not* what's on disk; the cleaned track is the most valuable
  artifact, and for unsupported-translation languages it is the whole
  feature.
- One timed subtitle file per successfully translated target language,
  same container format as input.
- When a selected target equals the source it is skipped **with a
  visible note** in the job row ("English skipped — source is already
  English; cleaned track saved"), never silently.
- Cheap adjunct (in scope, trivially available from reflow output): a
  flattened plain-text transcript `name.<sourceLang>.txt`.
- The original downloaded file is never modified.

## Malformed-input policy

- Parsing is per-cue best-effort: skip unparseable blocks, count them,
  surface the count via the existing `doneWithWarning` mechanism.
- Whole-file reject (existing `showNotice` pattern, job marked failed)
  only when zero valid cues parse. Never write N empty output files.
- Cues sorted by start before processing; `endMs` clamped ≥ `startMs`.

## Testing plan (TDD; council-hardened)

Pure and unit-tested: timestamp round-trip identity; BOM/CRLF/EOF
handling; VTT header-block and `Language:` capture; NOTE/STYLE/REGION
skipping; entity decode/re-escape; mid-word tag-chunk stripping
(byte-for-byte concatenation fixture from a real sample); the emptiness
predicate (U+00A0, zero-width); VTT structural reflow; SRT
whole-line-dedup with run detector (clean-file pass-through
byte-identical, genuine-repeats preservation); silence-gap fixture
(gaps preserved); fold-direction; sentence grouping + proportional
redistribution; output-name collision rules incl. trailing-lang-code
stripping; out-of-order batch response correlation via clientIdentifier
(fake engine shuffles responses); ingest routing for both filter sites;
mixed-folder rule.

**Real-fixture requirement** (replaces the old draft's "tuning pass"):
before the reflow algorithm is written, download several actual yt-dlp
caption files — an English talk, an Urdu track, a Japanese video, a
music video with a long instrumental gap — check at least one real
`.vtt` in as a fixture, and lock the reflow tests to them. Synthetic
fixtures alone are not acceptance.

NOT covered by automated tests (same boundary as the audio translation
feature): real `NLLanguageRecognizer` accuracy, real `TranslationSession`
output and pack-download behavior — verified manually on hardware,
including the two-consecutive-same-target-requests case.

## Out of scope (v1)

- A translation engine for Apple-unsupported languages (ur, bn, fa, pa,
  ps) — recorded follow-up; v1 ships the availability gate + cleaned
  track instead.
- Formats other than `.srt`/`.vtt` (`.sbv`, `.ttml`, `.ass`).
- Fetching captions directly from a YouTube URL — files the user
  already downloaded only; the app never contacts YouTube.
- Styling-faithful output (positioning, colors, karaoke timing).
- A cancel button for in-flight jobs (pre-existing app-wide gap,
  backlog).
