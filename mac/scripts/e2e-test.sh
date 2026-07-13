#!/usr/bin/env bash
# End-to-end engine test: synthesize speech -> convert like the app does -> transcribe.
# Mirrors WhisperEngine's exact pipeline (ffmpeg 16kHz mono wav -> whisper-cli).
set -euo pipefail

MODEL="$HOME/Library/Application Support/StenoDrop/models/ggml-small.bin"
WHISPER="$(command -v whisper-cli || echo /opt/homebrew/bin/whisper-cli)"
FFMPEG="$(command -v ffmpeg || echo /opt/homebrew/bin/ffmpeg)"

[[ -x "$WHISPER" ]] || { echo "FAIL: whisper-cli not found (brew install whisper-cpp)"; exit 1; }
[[ -x "$FFMPEG" ]] || { echo "FAIL: ffmpeg not found (brew install ffmpeg)"; exit 1; }
[[ -f "$MODEL" ]] || { echo "FAIL: model missing at $MODEL"; exit 1; }

WORK="$(mktemp -d /tmp/stenodrop-e2e.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

echo "1/3 Synthesizing test speech..."
say -o "$WORK/speech.aiff" "The quick brown fox jumps over the lazy dog. This is a StenoDrop engine test."
# Route through m4a to also cover the compressed-input path the app handles via ffmpeg.
"$FFMPEG" -y -hide_banner -loglevel error -i "$WORK/speech.aiff" -c:a aac "$WORK/speech.m4a"

echo "2/3 Converting to 16kHz mono wav (app pipeline)..."
"$FFMPEG" -y -hide_banner -loglevel error -nostdin -i "$WORK/speech.m4a" \
  -ar 16000 -ac 1 -c:a pcm_s16le "$WORK/audio.wav"

echo "3/3 Transcribing..."
"$WHISPER" -m "$MODEL" -f "$WORK/audio.wav" -l auto -otxt -of "$WORK/transcript" -np 2>/dev/null

TXT="$WORK/transcript.txt"
[[ -s "$TXT" ]] || { echo "FAIL: no transcript produced"; exit 1; }

TRANSCRIPT="$(cat "$TXT")"
echo "Transcript: $TRANSCRIPT"
shopt -s nocasematch
if [[ "$TRANSCRIPT" == *"quick brown fox"* && "$TRANSCRIPT" == *"lazy dog"* ]]; then
  echo "PASS"
else
  echo "FAIL: expected phrases not found"
  exit 1
fi
