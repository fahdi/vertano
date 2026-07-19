# StenoDrop Cross-Platform Design (Windows + Linux)

Date: 2026-07-14 · Status: Approved (user directive: full SDLC + TDD)

## Decision

One Tauri v2 + Rust app in `desktop/` targets **Windows and Linux**. macOS
keeps the native SwiftUI app in `mac/` as flagship (revisit consolidation
only if desktop/ reaches feature parity and Mac users accept it).

## Why Tauri + whisper-rs

- Single codebase, tiny installers (MSI/NSIS, AppImage/deb), Rust core.
- `whisper-rs` links whisper.cpp statically → one binary, no sidecar or
  PATH dependency (unlike the Mac app's brew approach — Windows users
  cannot be asked to install Homebrew).
- Audio decode in-process via `symphonia` (mp3/m4a/flac/ogg/wav) +
  `rubato` resample to 16 kHz mono — **no ffmpeg dependency at all**.
- Tauri 2 has a mobile path (iOS/Android) → honest "mobile coming soon".

## Architecture (desktop/)

```
src-tauri/src/
  engine/decode.rs     symphonia+rubato → 16k mono f32 (pure, unit-tested)
  engine/whisper.rs    whisper-rs wrapper: model load, transcribe(translate, lang)
  engine/scan.rs       folder ingest: recursive, extension filter, dedupe (pure, unit-tested)
  engine/output.rs     txt-beside-source naming incl. collision fallback name.ext.txt (pure, unit-tested)
  queue.rs             sequential job runner, status events → UI
  model.rs             ggml-small download w/ progress, size+status validation (mirror Mac fixes)
  commands.rs          tauri commands: ingest, start, cancel, settings
ui/                    plain HTML/CSS/JS (no framework), StenoDrop court-transcript brand
```

## TDD contract (tests written before implementation)

- `scan.rs`: extension filter, recursion, hidden-file skip, dedupe, sort
- `output.rs`: naming, same-basename collision (a.mp3+a.wav), unicode names
- `decode.rs`: golden tiny fixtures (wav/mp3/flac) → expected sample rate/mono
- `whisper.rs`: integration test gated behind `--ignored` (needs model) —
  jfk.wav fixture transcribes to text containing "country"
- Queue: state-machine unit tests (per-file failure continues queue)
- UI smoke: `tauri-driver`/WebDriver later (backlog, not v1 gate)

## Feature parity for v0.2.0 desktop

Drag-drop files/folders, batch queue UI, language picker + translate toggle
(same 19 languages), txt-beside-source, model download screen, quit-mid-batch
confirm. Recording feature stays Mac-only for now.

## CI / Release (GitHub Actions)

`release.yml` on tag `v*`:
- job mac: swift build + make-app.sh + zip (existing script)
- job windows (windows-latest): tauri build → NSIS .exe installer
- job linux (ubuntu-22.04): tauri build → AppImage + .deb
- all artifacts attached to the GitHub Release; checksums file
- `test.yml` on PR/push: cargo test + swift build as matrix

## Website

Download section with three OS cards (JS highlights visitor's OS), linking
to latest-release assets; Windows/Linux cards say "beta". Mobile card:
"coming soon". SmartScreen note for unsigned Windows builds.

## Out of scope v0.2.0

GPU accel on Win/Linux (CPU small model is fine), code signing certs
(Windows cert ~$200/yr — later), auto-update, diarization, mobile builds.
