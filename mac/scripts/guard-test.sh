#!/usr/bin/env bash
# Unit-level check for the Devanagari guard (TextScript.isMajorityDevanagari).
# No Swift test target exists yet, so this compiles a throwaway driver
# alongside the real TextScript.swift with swiftc and asserts on 3 samples:
#   1. Pure Urdu (Perso-Arabic) script  -> false
#   2. Pure Devanagari script           -> true
#   3. Mixed/English text               -> false
set -euo pipefail

cd "$(dirname "$0")/.."
SRC="Sources/Vertano/Engine/TextScript.swift"
[[ -f "$SRC" ]] || { echo "FAIL: $SRC not found"; exit 1; }

WORK="$(mktemp -d /tmp/vertano-guard-test.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

cat > "$WORK/main.swift" <<'EOF'
import Foundation

// Sample 1: pure Urdu (Perso-Arabic script) — must NOT be flagged Devanagari.
let urduSample = "یہ ایک جملہ ہے جو اردو رسم الخط میں لکھا گیا ہے۔"

// Sample 2: pure Devanagari (Hindi script) — MUST be flagged.
let devanagariSample = "यह एक वाक्य है जो देवनागरी लिपि में लिखा गया है।"

// Sample 3: mixed/English text — must NOT be flagged.
let englishSample = "This is a plain English sentence with no special script at all."

var failures = 0

func check(_ name: String, _ actual: Bool, expected: Bool) {
    if actual == expected {
        print("PASS: \(name) -> \(actual)")
    } else {
        print("FAIL: \(name) -> got \(actual), expected \(expected)")
        failures += 1
    }
}

check("pure Urdu script", TextScript.isMajorityDevanagari(urduSample), expected: false)
check("pure Devanagari script", TextScript.isMajorityDevanagari(devanagariSample), expected: true)
check("mixed English text", TextScript.isMajorityDevanagari(englishSample), expected: false)

if failures > 0 {
    print("\(failures) check(s) failed")
    exit(1)
}
print("All guard checks passed")
EOF

echo "Compiling guard-test driver..."
swiftc -O "$SRC" "$WORK/main.swift" -o "$WORK/guard-test"

echo "Running guard-test..."
if "$WORK/guard-test"; then
    echo "PASS"
else
    echo "FAIL: guard-test assertions failed"
    exit 1
fi
