#!/usr/bin/env bash
# Caption smoke test: parse + reflow + chunk the checked-in real yt-dlp
# fixture end-to-end (fake translation engine) via the test suite.
# Usage: ./scripts/caption-smoke-test.sh
set -euo pipefail

cd "$(dirname "$0")/.."

FIXTURE="Tests/StenoDropTests/Fixtures/real-yt-dlp-rollup.en.vtt"
[[ -f "$FIXTURE" ]] || { echo "Missing fixture: $FIXTURE"; exit 1; }

echo "Running caption parse/reflow/pipeline smoke tests against $FIXTURE ..."
swift test \
    --filter CaptionFileTests.testRealYtDlpFixtureParses \
    --filter CaptionReflowTests \
    --filter CaptionPipelineTests

echo "Caption smoke test passed."
