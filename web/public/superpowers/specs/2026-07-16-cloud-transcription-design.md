# Vertano Web — Optional Cloud Transcription (Large Model)

Date: 2026-07-16 · Status: Approved (web app only, opt-in mode picker)

## Why this exists

The web app runs Whisper `base` locally (~205 MB, safe to load in a
browser tab). Whisper's biggest model, `large-v3` (~2.9 GB), gives
meaningfully better accuracy, especially on names and non-English audio,
but is too large/slow to reliably run inside a browser tab via
WebAssembly on most devices. The fix is a genuine choice, not a silent
default: let the visitor pick **Offline** (today's behavior) or **Cloud**
(sends the audio to a server running the large model, gets text back).

## The trade-off, stated plainly (for the UI copy)

**Offline** — private by construction. Nothing ever leaves the device.
Free, always available, no account. Ceiling on accuracy is the small
model that fits in a browser tab.

**Cloud** — best possible accuracy (Whisper large-v3, same engine, much
bigger model). Requires the audio to be sent to a server for the
duration of the request (not stored, not logged, deleted immediately
after the transcript is returned — this must be true in the actual
implementation, not just the copy). Requires an internet connection.
Runs on infrastructure that costs real money to operate, so it may be
rate-limited.

## Architecture

- **Client**: a mode picker (Offline / Cloud) added to the existing
  language + output-checklist controls in `docs/app/`. Cloud mode posts
  the decoded/resampled audio to a configurable API endpoint instead of
  running the local Transformers.js pipeline. Client checks a `/health`
  endpoint on load to know whether Cloud is currently reachable, and
  disables the option with a clear note if not, rather than letting a
  user pick it and hit a dead server.
- **Server**: a new repo, `stenodrop-server`. Whisper.cpp (same engine
  family as every native app) built with the `large-v3` or
  `large-v3-turbo` ggml model, wrapped in a small HTTP API (`/transcribe`,
  `/health`). Whisper.cpp was chosen over a Python stack to stay
  consistent with the rest of this project's engine choice and keep the
  container lean.
- **Deployment target**: isupercoder.com's existing server. This repo
  ships fully containerized (Dockerfile + docker-compose) with a README
  covering exactly how to run it there. Actually deploying it is a
  separate step from writing it, see "What I cannot do" below.

## API contract (both sides build against this)

```
GET  /health
     -> 200 { "status": "ok", "model": "large-v3-turbo" }

POST /transcribe
     multipart/form-data: file (audio/wav, 16kHz mono preferred),
                           language (string, default "auto"),
                           translate ("true" | "false")
     -> 200 { "text": "...", "language_used": "..." }
     -> 400 { "error": "..." }   (bad input, e.g. file too large)
     -> 429 { "error": "..." }   (rate limited)
     -> 500 { "error": "..." }   (transcription failed)
```

## Abuse protection (non-negotiable, since this would be a free public endpoint)

- Max upload size (e.g. 50 MB) rejected with 400 before processing.
- Per-IP rate limit (e.g. 10 requests / 10 minutes) returning 429.
- CORS locked to `https://fahdi.github.io` (not a wildcard).
- Request timeout so one slow job can't block the queue indefinitely.
- Audio is processed in memory/temp storage and deleted immediately
  after the response is sent. No logging of audio content or transcript
  text, only aggregate metrics (request count, duration, errors).

## What I cannot do

I do not have SSH keys, a hosting panel login, or any established
connection to isupercoder.com's server in this environment. I can build
and fully verify the server locally/in a container, but making it live
on that host requires either the user deploying the container
themselves (README covers this exactly) or granting explicit deploy
access for this purpose.

## Out of scope (v1)

Auth accounts, per-user history, batch cloud jobs (cloud mode processes
one file at a time to start), GPU-specific optimization (CPU inference
is the safe default; GPU is a deploy-time choice documented but not
required).
