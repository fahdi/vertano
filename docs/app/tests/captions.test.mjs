// Tests for docs/app/captions.js, ported from the Mac implementation's
// suite (mac/Tests/StenoDropTests/CaptionFileTests.swift, CaptionJobTests.swift,
// CaptionChunkingTests.swift). The normative rules live in
// docs/superpowers/specs/2026-07-17-mac-caption-translation-design.md.
// Runs with bare node and zero dependencies:
//   node --test docs/app/tests/captions.test.mjs
//   node --test "docs/app/tests/**/*.test.mjs"
// (Recent Node versions treat a bare directory argument as a module entry
// point rather than a discovery root, so pass the file or a glob.)
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

import {
  parseCaptions,
  parseTimestamp,
  formatTimestamp,
  decodeEntities,
  isEffectivelyEmpty,
  reflow,
  chunkCues,
  redistribute,
  serializeCaptions,
  strippedBaseName,
  captionOutputName,
} from "../captions.js";

const encoder = new TextEncoder();
const parse = (text, format = "vtt") => parseCaptions(encoder.encode(text), format);

function fixture(name) {
  return new Uint8Array(readFileSync(new URL("./fixtures/" + name, import.meta.url)));
}

// ---------------------------------------------------------------------------
// Real fixtures: parsing
// ---------------------------------------------------------------------------

test("real yt-dlp fixture parses", () => {
  const file = parseCaptions(fixture("real-yt-dlp-rollup.en.vtt"), "vtt");
  assert.equal(file.cues.length, 103);
  assert.equal(file.language, "en");
  assert.equal(file.skippedBlockCount, 0);
  assert.deepEqual(file.warnings, []);

  const first = file.cues[0];
  assert.equal(first.startMs, 320);
  assert.equal(first.endMs, 18790);
  assert.deepEqual(first.lines.map((l) => l.text), [" ", "[Music]"]);
  assert.equal(first.lines[1].hadInlineTimestamps, false);

  const third = file.cues[2];
  assert.equal(third.startMs, 18800);
  assert.equal(third.endMs, 21790);
  assert.equal(third.lines[1].text, "We're no strangers to");
  assert.equal(third.lines[1].hadInlineTimestamps, true);
  assert.equal(third.lines[0].hadInlineTimestamps, false);

  const last = file.cues[file.cues.length - 1];
  assert.equal(last.startMs, 206840);
  assert.equal(last.endMs, 211879);
  assert.equal(last.lines[0].text, "make you cry. Never going to say");
  assert.equal(last.lines[1].text, "goodbye. Never going to say goodbye.");
  assert.equal(last.lines[1].hadInlineTimestamps, true);
});

test("real C-SPAN fixture parses best-effort", () => {
  const file = parseCaptions(fixture("real-cspan-rollup-sample.vtt"), "vtt");
  assert.equal(file.cues.length, 9);
  assert.equal(file.language, "en");
  assert.equal(file.skippedBlockCount, 8);
  assert.ok(file.warnings.some((w) => w.includes("8")), "skipped-block warning must carry the count");

  // Building cue whose tagged line chunks mid-word (TH<c>E </c><c>SE</c>...).
  const building = file.cues[2];
  assert.equal(building.startMs, 235334);
  assert.equal(building.endMs, 237236);
  assert.equal(building.lines[0].text, "THE SERGEANT AT ARMS: MADAM");
  assert.equal(building.lines[1].text, "SPEAKER, THE VICE PRESIDENT AND ");
  assert.equal(building.lines[1].hadInlineTimestamps, true);

  // Long static cue: end time crosses into a later minute.
  const long = file.cues[4];
  assert.equal(long.startMs, 237369);
  assert.equal(long.endMs, 469535);
  assert.equal(long.lines[1].text, "THE UNITED STATES SENATE.");
});

// ---------------------------------------------------------------------------
// Decode ladder
// ---------------------------------------------------------------------------

function utf16le(text) {
  const out = new Uint8Array(text.length * 2);
  for (let i = 0; i < text.length; i++) {
    const code = text.charCodeAt(i);
    out[i * 2] = code & 0xff;
    out[i * 2 + 1] = code >> 8;
  }
  return out;
}

test("UTF-16LE BOM SRT decodes", () => {
  const srt = "1\n00:00:01,000 --> 00:00:02,000\ncafé naïve\n";
  const body = utf16le(srt);
  const data = new Uint8Array(2 + body.length);
  data.set([0xff, 0xfe], 0);
  data.set(body, 2);
  const file = parseCaptions(data, "srt");
  assert.equal(file.cues.length, 1);
  assert.equal(file.cues[0].lines[0].text, "café naïve");
  assert.deepEqual(file.warnings, []);
});

test("UTF-16BE BOM SRT decodes", () => {
  const srt = "1\n00:00:01,000 --> 00:00:02,000\ncafé\n";
  const le = utf16le(srt);
  const be = new Uint8Array(le.length);
  for (let i = 0; i < le.length; i += 2) {
    be[i] = le[i + 1];
    be[i + 1] = le[i];
  }
  const data = new Uint8Array(2 + be.length);
  data.set([0xfe, 0xff], 0);
  data.set(be, 2);
  const file = parseCaptions(data, "srt");
  assert.equal(file.cues[0].lines[0].text, "café");
  assert.deepEqual(file.warnings, []);
});

test("UTF-8 BOM is stripped post-decode", () => {
  const body = encoder.encode("1\n00:00:01,000 --> 00:00:02,000\nhello\n");
  const data = new Uint8Array(3 + body.length);
  data.set([0xef, 0xbb, 0xbf], 0);
  data.set(body, 3);
  const file = parseCaptions(data, "srt");
  assert.equal(file.cues.length, 1);
  assert.ok(!file.cues[0].lines[0].text.startsWith("﻿"));
  assert.deepEqual(file.warnings, []);
});

test("Windows-1252 fallback decodes with warning", () => {
  // "café" and "über" with CP1252 single-byte accents, invalid as UTF-8.
  const head = encoder.encode("1\n00:00:01,000 --> 00:00:02,000\ncaf");
  const tail1 = encoder.encode("\n");
  const tail2 = encoder.encode("ber\n");
  const data = new Uint8Array(head.length + 1 + tail1.length + 1 + tail2.length);
  let o = 0;
  data.set(head, o); o += head.length;
  data[o++] = 0xe9; // é
  data.set(tail1, o); o += tail1.length;
  data[o++] = 0xfc; // ü
  data.set(tail2, o);
  const file = parseCaptions(data, "srt");
  assert.deepEqual(file.cues[0].lines.map((l) => l.text), ["café", "über"]);
  assert.ok(file.warnings.some((w) => w.includes("Windows-1252")));
});

// ---------------------------------------------------------------------------
// Timestamps
// ---------------------------------------------------------------------------

test("SRT timestamp round-trip is identity", () => {
  for (const stamp of ["00:00:00,000", "01:02:03,456", "23:59:59,999", "100:00:00,001"]) {
    const ms = parseTimestamp(stamp, "srt");
    assert.notEqual(ms, null, stamp);
    assert.equal(formatTimestamp(ms, "srt"), stamp);
  }
});

test("VTT timestamp round-trip is identity", () => {
  for (const stamp of ["00:00:00.320", "00:03:55.201", "01:02:03.456", "100:00:00.001"]) {
    const ms = parseTimestamp(stamp, "vtt");
    assert.notEqual(ms, null, stamp);
    assert.equal(formatTimestamp(ms, "vtt"), stamp);
  }
});

test("VTT hours are optional on parse", () => {
  assert.equal(parseTimestamp("01:02.500", "vtt"), 62500);
  assert.equal(parseTimestamp("00:01:02.500", "vtt"), 62500);
});

test("fractional seconds round, never truncate", () => {
  assert.equal(parseTimestamp("00:00:01.5", "vtt"), 1500);
  assert.equal(parseTimestamp("00:00:01.0006", "vtt"), 1001);
});

test("wrong separator rejected per format", () => {
  assert.equal(parseTimestamp("00:00:01.000", "srt"), null);
  assert.equal(parseTimestamp("00:00:01,000", "vtt"), null);
});

// ---------------------------------------------------------------------------
// Line endings, EOF, VTT grammar
// ---------------------------------------------------------------------------

test("CRLF and bare CR normalized", () => {
  const srt = "1\r\n00:00:01,000 --> 00:00:02,000\r\nfirst\r\r2\r00:00:02,000 --> 00:00:03,000\rsecond";
  const file = parse(srt, "srt");
  assert.equal(file.cues.length, 2);
  assert.equal(file.cues[0].lines[0].text, "first");
  assert.equal(file.cues[1].lines[0].text, "second");
});

test("EOF terminates the final block without trailing newline", () => {
  const file = parse("1\n00:00:01,000 --> 00:00:02,000\nonly cue", "srt");
  assert.equal(file.cues.length, 1);
  assert.equal(file.cues[0].lines[0].text, "only cue");
});

test("VTT header with trailing text tolerated", () => {
  const file = parse("WEBVTT - generated by someone\n\n00:00:01.000 --> 00:00:02.000\nhi\n");
  assert.equal(file.cues.length, 1);
  assert.equal(file.language, null);
});

test("VTT header block consumed and Language captured", () => {
  const file = parse("WEBVTT\nKind: captions\nLanguage: ur\n\n00:00:01.000 --> 00:00:02.000\nhi\n");
  assert.equal(file.language, "ur");
  assert.equal(file.cues.length, 1);
  assert.equal(file.skippedBlockCount, 0);
});

test("NOTE, STYLE, REGION blocks skipped silently", () => {
  const vtt = [
    "WEBVTT",
    "",
    "NOTE this is a comment",
    "spanning two lines",
    "",
    "STYLE",
    "::cue { color: red }",
    "",
    "REGION",
    "id:one",
    "",
    "00:00:01.000 --> 00:00:02.000",
    "hi",
    "",
  ].join("\n");
  const file = parse(vtt);
  assert.equal(file.cues.length, 1);
  assert.equal(file.skippedBlockCount, 0);
  assert.deepEqual(file.warnings, []);
});

test("cue identifiers and settings parsed past", () => {
  const vtt = "WEBVTT\n\nintro cue\n00:00:01.000 --> 00:00:02.000 align:start position:0%\nhi\n";
  const file = parse(vtt);
  assert.equal(file.cues.length, 1);
  assert.equal(file.cues[0].startMs, 1000);
  assert.equal(file.cues[0].endMs, 2000);
  assert.deepEqual(file.cues[0].lines.map((l) => l.text), ["hi"]);
});

// ---------------------------------------------------------------------------
// Tag stripping
// ---------------------------------------------------------------------------

test("mid-word tag spans deleted byte-for-byte", () => {
  const raw =
    "TH<00:03:54.366><c>E </c><00:03:54.399><c>SE</c><00:03:54.433><c>RG</c>" +
    "<00:03:54.466><c>EA</c><00:03:54.500><c>NT</c><00:03:54.533><c> A</c>" +
    "<00:03:54.566><c>T </c><00:03:54.600><c>AR</c><00:03:54.633><c>MS</c>" +
    "<00:03:54.666><c>: </c><00:03:54.700><c>MA</c><00:03:54.733><c>DA</c>" +
    "<00:03:54.766><c>M</c><00:03:55.101><c> </c>";
  const file = parse(`WEBVTT\n\n00:00:01.000 --> 00:00:02.000\n${raw}\n`);
  assert.equal(file.cues[0].lines[0].text, "THE SERGEANT AT ARMS: MADAM ");
  assert.equal(file.cues[0].lines[0].hadInlineTimestamps, true);
});

test("style tags stripped without timestamp flag", () => {
  const file = parse("WEBVTT\n\n00:00:01.000 --> 00:00:02.000\n<i>hello</i> <b>world</b>\n");
  assert.equal(file.cues[0].lines[0].text, "hello world");
  assert.equal(file.cues[0].lines[0].hadInlineTimestamps, false);
});

test("ruby annotation dropped", () => {
  const file = parse("WEBVTT\n\n00:00:01.000 --> 00:00:02.000\n<ruby>漢<rt>かん</rt></ruby>字\n");
  assert.equal(file.cues[0].lines[0].text, "漢字");
});

test("voice tag becomes speaker prefix", () => {
  const file = parse("WEBVTT\n\n00:00:01.000 --> 00:00:02.000\n<v Fred Rogers>Hello there</v>\n");
  const line = file.cues[0].lines[0];
  assert.equal(line.text, "Fred Rogers: Hello there");
  assert.equal(line.speakerPrefix, "Fred Rogers: ");
});

test("line without voice tag has no speaker prefix", () => {
  const file = parse("WEBVTT\n\n00:00:01.000 --> 00:00:02.000\nplain line\n");
  assert.equal(file.cues[0].lines[0].speakerPrefix, null);
});

// ---------------------------------------------------------------------------
// Entities
// ---------------------------------------------------------------------------

test("entities decoded on parse", () => {
  const file = parse("WEBVTT\n\n00:00:01.000 --> 00:00:02.000\nA &amp; B &lt;c&gt; &#65;&#x42;\n");
  assert.equal(file.cues[0].lines[0].text, "A & B <c> AB");
});

test("entity decode happens after tag stripping", () => {
  // "&lt;c&gt;" must survive as literal text, never be treated as a tag.
  const file = parse("WEBVTT\n\n00:00:01.000 --> 00:00:02.000\nkeep &lt;c&gt; literal\n");
  assert.equal(file.cues[0].lines[0].text, "keep <c> literal");
});

test("directional and nbsp entities decoded", () => {
  const file = parse("WEBVTT\n\n00:00:01.000 --> 00:00:02.000\na&nbsp;b&lrm;c&rlm;d\n");
  assert.equal(file.cues[0].lines[0].text, "a b‎c‏d");
});

// ---------------------------------------------------------------------------
// Emptiness predicate
// ---------------------------------------------------------------------------

test("emptiness predicate", () => {
  assert.equal(isEffectivelyEmpty(""), true);
  assert.equal(isEffectivelyEmpty(" "), true);
  assert.equal(isEffectivelyEmpty(" \t "), true);
  assert.equal(isEffectivelyEmpty(" "), true);
  assert.equal(isEffectivelyEmpty("&nbsp;"), true);
  assert.equal(isEffectivelyEmpty("​‎‏"), true);
  assert.equal(isEffectivelyEmpty("&lrm;&rlm;"), true);
  assert.equal(isEffectivelyEmpty("a"), false);
  assert.equal(isEffectivelyEmpty(" x"), false);
  assert.equal(isEffectivelyEmpty("[Music]"), false);
});

// ---------------------------------------------------------------------------
// Malformed input
// ---------------------------------------------------------------------------

test("malformed block skipped between valid cues", () => {
  const srt = [
    "1",
    "00:00:01,000 --> 00:00:02,000",
    "first",
    "",
    "this block has no timestamp line",
    "at all",
    "",
    "2",
    "00:00:03,000 --> 00:00:04,000",
    "second",
    "",
  ].join("\n");
  const file = parse(srt, "srt");
  assert.equal(file.cues.length, 2);
  assert.equal(file.skippedBlockCount, 1);
  assert.ok(file.warnings.some((w) => w.includes("1")));
});

test("zero valid cues throws distinctly", () => {
  assert.throws(() => parse("not a caption file\n\nat all\n", "srt"), /usable|valid/i);
  assert.throws(() => parseCaptions(new Uint8Array(0), "vtt"), /usable|valid/i);
});

// ---------------------------------------------------------------------------
// Serialization
// ---------------------------------------------------------------------------

test("SRT round-trip identity", () => {
  const srt = [
    "1",
    "00:00:01,000 --> 00:00:02,500",
    "Hello there",
    "",
    "2",
    "00:00:02,500 --> 00:00:04,000",
    "Second cue",
    "line two",
    "",
  ].join("\n");
  const file = parse(srt, "srt");
  assert.equal(serializeCaptions(file.cues, "srt"), srt);
});

test("VTT round-trip identity", () => {
  const vtt = [
    "WEBVTT",
    "Language: en",
    "",
    "00:00:01.000 --> 00:00:02.500",
    "Hello there",
    "",
    "00:00:02.500 --> 00:00:04.000",
    "Second cue",
    "line two",
    "",
  ].join("\n");
  const file = parse(vtt);
  assert.equal(serializeCaptions(file.cues, "vtt", file.language), vtt);
});

test("SRT indices ignored on parse and regenerated on write", () => {
  const srt = "7\n00:00:01,000 --> 00:00:02,000\nfirst\n\n42\n00:00:03,000 --> 00:00:04,000\nsecond\n";
  const file = parse(srt, "srt");
  const out = serializeCaptions(file.cues, "srt");
  assert.ok(out.startsWith("1\n00:00:01,000"));
  assert.ok(out.includes("\n\n2\n00:00:03,000"));
  assert.ok(!out.includes("42"));
});

test("VTT write re-escapes ampersand and less-than", () => {
  const cues = [
    { startMs: 1000, endMs: 2000, lines: [{ text: "AT&T <hello> done", hadInlineTimestamps: false, speakerPrefix: null }] },
  ];
  assert.ok(serializeCaptions(cues, "vtt").includes("AT&amp;T &lt;hello> done"));
  assert.ok(serializeCaptions(cues, "srt").includes("AT&T <hello> done"));
});

test("serialized output is LF with no BOM and trailing newline", () => {
  const cues = [{ startMs: 0, endMs: 1000, lines: [{ text: "hé", hadInlineTimestamps: false, speakerPrefix: null }] }];
  const out = serializeCaptions(cues, "vtt");
  assert.ok(!out.startsWith("﻿"));
  assert.ok(!out.includes("\r"));
  assert.ok(out.endsWith("\n"));
});

// ---------------------------------------------------------------------------
// Reflow
// ---------------------------------------------------------------------------

// Minimal but structurally faithful yt-dlp rolling VTT: building cues carry
// the previous line untagged plus the new tagged line; ~10 ms static echo
// cues hold the completed line and a filler. Built with explicit " " entries
// so editors can never silently strip the meaningful trailing whitespace.
const rollingVTT = [
  "WEBVTT",
  "Kind: captions",
  "Language: en",
  "",
  "00:00:00.000 --> 00:00:02.000 align:start position:0%",
  " ",
  "alpha<00:00:00.500><c> beta</c>",
  "",
  "00:00:02.000 --> 00:00:02.010 align:start position:0%",
  "alpha beta",
  " ",
  "",
  "00:00:02.010 --> 00:00:04.000 align:start position:0%",
  "alpha beta",
  "gamma<00:00:02.500><c> delta</c>",
  "",
  "00:00:04.000 --> 00:00:04.010 align:start position:0%",
  "gamma delta",
  " ",
  "",
  "00:00:04.010 --> 00:00:06.000 align:start position:0%",
  "gamma delta",
  "epsilon<00:00:04.500><c> zeta</c>",
  "",
  "00:00:06.000 --> 00:00:06.010 align:start position:0%",
  "epsilon zeta",
  " ",
  "",
  "00:00:06.010 --> 00:00:08.000 align:start position:0%",
  "epsilon zeta",
  "eta<00:00:06.500><c> theta</c>",
  "",
].join("\n");

test("rolling VTT deduplicates and retimes", () => {
  const file = parse(rollingVTT);
  const result = reflow(file.cues);
  assert.deepEqual(
    result.cues.map((c) => c.lines.map((l) => l.text)),
    [["alpha beta"], ["gamma delta"], ["epsilon zeta"], ["eta theta"]]
  );
  assert.deepEqual(result.cues.map((c) => c.startMs), [0, 2010, 4010, 6010]);
  // Each completed line spans to the next building cue's start (<= epsilon);
  // the final cue keeps its own end.
  assert.deepEqual(result.cues.map((c) => c.endMs), [2010, 4010, 6010, 8000]);
  assert.deepEqual([...result.runBoundaries].sort(), [0]);
});

test("SRT rolling deduplicates without tags", () => {
  const srt = [
    "1", "00:00:00,000 --> 00:00:02,000", "alpha beta", "",
    "2", "00:00:02,000 --> 00:00:02,010", "alpha beta", "",
    "3", "00:00:02,010 --> 00:00:04,000", "alpha beta", "gamma delta", "",
    "4", "00:00:04,000 --> 00:00:04,010", "gamma delta", "",
    "5", "00:00:04,010 --> 00:00:06,000", "gamma delta", "epsilon zeta", "",
    "6", "00:00:06,000 --> 00:00:06,010", "epsilon zeta", "",
    "7", "00:00:06,010 --> 00:00:08,000", "epsilon zeta", "eta theta", "",
  ].join("\n");
  const file = parse(srt, "srt");
  const result = reflow(file.cues);
  assert.deepEqual(
    result.cues.map((c) => c.lines.map((l) => l.text)),
    [["alpha beta"], ["gamma delta"], ["epsilon zeta"], ["eta theta"]]
  );
});

test("chant SRT passes through byte-identical", () => {
  const chant = [
    "1", "00:00:00,000 --> 00:00:01,000", "Hey!", "",
    "2", "00:00:01,000 --> 00:00:02,000", "Hey!", "",
    "3", "00:00:02,000 --> 00:00:03,000", "Hey!", "",
    "4", "00:00:03,000 --> 00:00:04,000", "Hey!", "",
  ].join("\n");
  const file = parse(chant, "srt");
  const result = reflow(file.cues);
  assert.deepEqual(result.cues, file.cues);
  assert.equal(result.runBoundaries.size, 0);
  assert.equal(serializeCaptions(result.cues, "srt"), chant);
});

test("tag-free manual VTT passes through", () => {
  const manual = [
    "WEBVTT",
    "",
    "00:00:01.000 --> 00:00:03.000",
    "Hello there,",
    "how are you?",
    "",
    "00:00:10.000 --> 00:00:12.000",
    "I'm fine.",
    "",
  ].join("\n");
  const file = parse(manual);
  const result = reflow(file.cues);
  assert.deepEqual(result.cues, file.cues);
  assert.equal(result.runBoundaries.size, 0);
});

test("karaoke VTT is preserved", () => {
  // Progressive karaoke: single-line cues with inline timestamps,
  // re-highlighting the same text across consecutive cues. Bare equality
  // between single-line blocks never counts as a line-shift pair, so no run
  // is detected and every cue passes through unchanged.
  const karaoke = [
    "WEBVTT",
    "",
    "00:00:00.000 --> 00:00:02.500",
    "Never<00:00:00.800> gonna<00:00:01.600> give",
    "",
    "00:00:02.500 --> 00:00:05.000",
    "Never<00:00:03.300> gonna<00:00:04.100> give",
    "",
    "00:00:05.000 --> 00:00:07.500",
    "you<00:00:05.800> up, never<00:00:06.600> gonna",
    "",
    "00:00:07.500 --> 00:00:10.000",
    "you<00:00:08.300> up, never<00:00:09.100> gonna",
    "",
    "00:00:10.000 --> 00:00:12.500",
    "let<00:00:10.800> you<00:00:11.600> down",
    "",
  ].join("\n");
  const file = parse(karaoke);
  assert.ok(file.cues.every((c) => c.lines.every((l) => l.hadInlineTimestamps)));
  const result = reflow(file.cues);
  assert.deepEqual(result.cues, file.cues);
  assert.equal(result.runBoundaries.size, 0);
});

test("overlapping speaker cue is transparent to the run", () => {
  const vtt = [
    "WEBVTT",
    "",
    "00:00:00.000 --> 00:00:02.000",
    "alpha beta",
    "",
    "00:00:02.000 --> 00:00:04.000",
    "alpha beta",
    "gamma delta",
    "",
    "00:00:04.000 --> 00:00:06.000",
    "gamma delta",
    "epsilon zeta",
    "",
    "00:00:04.500 --> 00:00:05.500",
    "Crowd: Whoa!",
    "",
    "00:00:06.000 --> 00:00:08.000",
    "epsilon zeta",
    "eta theta",
    "",
    "00:00:08.000 --> 00:00:10.000",
    "eta theta",
    "iota kappa",
    "",
    "00:00:10.000 --> 00:00:12.000",
    "iota kappa",
    "lambda mu",
    "",
  ].join("\n");
  const file = parse(vtt);
  const result = reflow(file.cues);
  // One run despite the overlap: it is transparent for membership counting.
  assert.deepEqual([...result.runBoundaries].sort(), [0]);
  assert.deepEqual(result.cues.map((c) => c.lines.map((l) => l.text)), [
    ["alpha beta"],
    ["gamma delta"],
    // Overlap pair's dedup skipped: the duplicate first line stays.
    ["gamma delta", "epsilon zeta"],
    ["Crowd: Whoa!"],
    // The dedup test compares against the last GLOBALLY emitted line (the
    // interjection), so this first line survives too.
    ["epsilon zeta", "eta theta"],
    // Run resumed: dedup works again after the overlap.
    ["iota kappa"],
    ["lambda mu"],
  ]);
  assert.deepEqual(
    result.cues.map((c) => c.startMs),
    [0, 2000, 4000, 4500, 6000, 8000, 10000]
  );
});

test("inter-run gap preserved and dedup is gap-independent", () => {
  // Second run resumes after a 5 s gap; its first block still repeats the
  // last globally emitted line, which must be dropped even though the gap
  // far exceeds epsilon.
  const vtt = rollingVTT + [
    "",
    "00:00:13.000 --> 00:00:15.000 align:start position:0%",
    "eta theta",
    "iota<00:00:13.500><c> kappa</c>",
    "",
    "00:00:15.000 --> 00:00:15.010 align:start position:0%",
    "iota kappa",
    " ",
    "",
    "00:00:15.010 --> 00:00:17.000 align:start position:0%",
    "iota kappa",
    "lambda<00:00:15.500><c> mu</c>",
    "",
    "00:00:17.000 --> 00:00:17.010 align:start position:0%",
    "lambda mu",
    " ",
    "",
    "00:00:17.010 --> 00:00:19.000 align:start position:0%",
    "lambda mu",
    "nu<00:00:17.500><c> xi</c>",
    "",
    "00:00:19.000 --> 00:00:19.010 align:start position:0%",
    "nu xi",
    " ",
    "",
    "00:00:19.010 --> 00:00:21.000 align:start position:0%",
    "nu xi",
    "omicron<00:00:19.500><c> pi</c>",
    "",
  ].join("\n");
  const file = parse(vtt);
  const result = reflow(file.cues);
  const texts = result.cues.map((c) => c.lines.map((l) => l.text).join(""));
  assert.deepEqual(texts, [
    "alpha beta", "gamma delta", "epsilon zeta", "eta theta",
    "iota kappa", "lambda mu", "nu xi", "omicron pi",
  ]);
  // The cue before the gap keeps its own end; the gap is preserved.
  assert.equal(result.cues[3].endMs, 8000);
  assert.equal(result.cues[4].startMs, 13000);
  assert.deepEqual([...result.runBoundaries].sort(), [0, 4]);
});

test("real yt-dlp fixture reflows to 52 cues starting with [Music]", () => {
  const file = parseCaptions(fixture("real-yt-dlp-rollup.en.vtt"), "vtt");
  const result = reflow(file.cues);

  // One [Music] cue + one cue per completed line.
  assert.equal(result.cues.length, 52);
  assert.deepEqual(result.cues[0].lines.map((l) => l.text), ["[Music]"]);
  assert.deepEqual(result.cues[1].lines.map((l) => l.text), ["We're no strangers to"]);
  assert.equal(result.cues[1].startMs, 18800);
  assert.equal(result.cues[1].endMs, 21800);
  assert.deepEqual(result.cues[2].lines.map((l) => l.text), ["love. You know the rules and so do"]);
  const last = result.cues[result.cues.length - 1];
  assert.deepEqual(last.lines.map((l) => l.text), ["goodbye. Never going to say goodbye."]);
  assert.equal(last.endMs, 211879);

  // No whole-line duplication survives reflow.
  const emitted = result.cues
    .flatMap((c) => c.lines.map((l) => l.text))
    .filter((t) => !isEffectivelyEmpty(t));
  for (let i = 1; i < emitted.length; i++) {
    assert.notEqual(emitted[i - 1], emitted[i]);
  }
});

// ---------------------------------------------------------------------------
// Chunking
// ---------------------------------------------------------------------------

function cue(startMs, endMs, text, speakerPrefix = null) {
  return {
    startMs,
    endMs,
    lines: [{ text, hadInlineTimestamps: false, speakerPrefix }],
  };
}

const ranges = (chunks) => chunks.map((c) => [c.start, c.end]);

test("gap at or above epsilon splits chunks", () => {
  const cues = [cue(0, 1000, "we shall fight"), cue(2000, 3000, "on the beaches")];
  assert.deepEqual(ranges(chunkCues(cues)), [[0, 1], [1, 2]]);
});

test("gap below epsilon does not split", () => {
  const cues = [cue(0, 1000, "we shall fight"), cue(1999, 3000, "on the beaches")];
  const chunks = chunkCues(cues);
  assert.deepEqual(ranges(chunks), [[0, 2]]);
  assert.equal(chunks[0].text, "we shall fight on the beaches");
});

test("punctuation-free gap-only chunking", () => {
  const cues = [
    cue(0, 900, "we shall fight"),
    cue(950, 1800, "on the beaches"),
    cue(2900, 3600, "we shall never"),
    cue(3700, 4400, "surrender"),
  ];
  const chunks = chunkCues(cues);
  assert.deepEqual(ranges(chunks), [[0, 2], [2, 4]]);
  assert.equal(chunks[0].text, "we shall fight on the beaches");
  assert.equal(chunks[1].text, "we shall never surrender");
});

test("sentence terminal characters end chunks", () => {
  for (const terminator of [".", "!", "?", "…", "。", "！", "？", "۔", "؟", "।"]) {
    const cues = [cue(0, 1000, "hello" + terminator), cue(1100, 2000, "world")];
    const chunks = chunkCues(cues);
    assert.equal(chunks.length, 2, `terminator ${terminator} must end the chunk`);
    assert.equal(chunks[0].text, "hello" + terminator);
    assert.equal(chunks[1].text, "world");
  }
});

test("non-terminal punctuation does not split", () => {
  for (const nonTerminator of [",", ":", ";", "-"]) {
    const cues = [cue(0, 1000, "hello" + nonTerminator), cue(1100, 2000, "world")];
    assert.equal(chunkCues(cues).length, 1, `${nonTerminator} must not end the chunk`);
  }
});

test("hard cap of twenty cues", () => {
  const cues = Array.from({ length: 25 }, (_, i) => cue(i * 100, i * 100 + 90, "word" + i));
  assert.deepEqual(ranges(chunkCues(cues)), [[0, 20], [20, 25]]);
});

test("hard cap of six hundred characters", () => {
  const text = "a".repeat(250);
  const cues = [cue(0, 900, text), cue(1000, 1900, text), cue(2000, 2900, text)];
  const chunks = chunkCues(cues);
  assert.deepEqual(ranges(chunks), [[0, 2], [2, 3]]);
  assert.equal(chunks[0].text.length, 501);
});

test("oversize single cue stays a whole chunk", () => {
  const big = "b".repeat(700);
  const cues = [cue(0, 900, "small text"), cue(1000, 1900, big)];
  const chunks = chunkCues(cues);
  assert.deepEqual(ranges(chunks), [[0, 1], [1, 2]]);
  assert.equal(chunks[1].text, big);
});

test("run boundaries never spanned", () => {
  const cues = [
    cue(0, 900, "end of one"),
    cue(950, 1800, "rolling run"),
    cue(1850, 2700, "start of the"),
    cue(2750, 3600, "next run"),
  ];
  assert.deepEqual(ranges(chunkCues(cues, new Set([2]))), [[0, 2], [2, 4]]);
});

test("overlapping cues are solo chunks", () => {
  const cues = [
    cue(0, 1000, "first speaker"),
    cue(900, 2000, "second speaker"),
    cue(1900, 3000, "third speaker"),
    cue(3050, 4000, "back to normal"),
  ];
  assert.deepEqual(ranges(chunkCues(cues)), [[0, 1], [1, 2], [2, 3], [3, 4]]);
});

test("speaker prefix stripped from chunk text", () => {
  const cues = [
    cue(0, 1000, "Bob: hello there", "Bob: "),
    cue(1100, 2000, "general kenobi"),
  ];
  const chunks = chunkCues(cues);
  assert.equal(chunks.length, 1);
  assert.equal(chunks[0].text, "hello there general kenobi");
});

test("multi-line cue joined with single spaces", () => {
  const cues = [
    {
      startMs: 0,
      endMs: 1000,
      lines: [
        { text: "first line", hadInlineTimestamps: false, speakerPrefix: null },
        { text: " ", hadInlineTimestamps: false, speakerPrefix: null },
        { text: "second line", hadInlineTimestamps: true, speakerPrefix: null },
      ],
    },
  ];
  const chunks = chunkCues(cues);
  assert.equal(chunks[0].text, "first line second line");
  assert.ok(!chunks[0].text.includes("\n"));
});

// ---------------------------------------------------------------------------
// Redistribution
// ---------------------------------------------------------------------------

const texts = (result) => result.cues.map((c) => c.lines[0].text);

// The spec's worked example: source grapheme lengths [12, 5, 23] give
// cumulative offsets at 12/40 and 17/40 of the 40-grapheme target; raw
// positions 12 and 17 land inside "brown" and "fox" and snap to the nearest
// earlier word boundaries.
test("worked example redistribution", () => {
  const cues = [
    cue(0, 2000, "twelve chars"),
    cue(2100, 3000, "hello"),
    cue(3100, 5000, "abcdefghij klmnopqrstuv"),
  ];
  const chunks = chunkCues(cues);
  assert.deepEqual(ranges(chunks), [[0, 3]]);

  const result = redistribute("The quick brown fox jumps over lazy dogs", chunks[0], cues, "en");
  assert.equal(result.usedSourceFallback, false);
  assert.deepEqual(texts(result), ["The quick", "brown", "fox jumps over lazy dogs"]);
  // Text only: timings identical to the source cues.
  assert.deepEqual(result.cues.map((c) => c.startMs), [0, 2100, 3100]);
  assert.deepEqual(result.cues.map((c) => c.endMs), [2000, 3000, 5000]);
  for (const t of texts(result)) {
    assert.equal(t, t.trim(), "no mid-word or padded edges");
  }
});

// Weights [1, 2] over a 12-grapheme Japanese string put the raw offset at 4,
// inside the token for "Japanese language"; it must snap (tie toward
// earlier) to 3.
test("redistribution snaps to word boundaries in a spaceless script", () => {
  const cues = [cue(0, 1000, "a"), cue(1100, 2000, "bc")];
  const result = redistribute(
    "これは日本語のテストです",
    { start: 0, end: 2, text: "a bc" },
    cues,
    "ja"
  );
  assert.equal(result.usedSourceFallback, false);
  assert.deepEqual(texts(result), ["これは", "日本語のテストです"]);
});

test("shrinking translation folds empty cue forward", () => {
  const cues = [
    cue(0, 1000, "aaaaaaaaaa"),
    cue(1100, 2000, "bbbbbbbbbb"),
    cue(2100, 3000, "cccccccccc"),
  ];
  const result = redistribute(
    "Yes okay",
    { start: 0, end: 3, text: "aaaaaaaaaa bbbbbbbbbb cccccccccc" },
    cues,
    "en"
  );
  assert.equal(result.usedSourceFallback, false);
  assert.deepEqual(texts(result), ["Yes", "okay"]);
  // The dropped middle cue's range folds into the previous survivor.
  assert.deepEqual(result.cues.map((c) => c.startMs), [0, 2100]);
  assert.deepEqual(result.cues.map((c) => c.endMs), [2000, 3000]);
});

test("zero-weight cue dropped and folded forward", () => {
  const cues = [cue(0, 1000, "aaaaa"), cue(1100, 1200, " "), cue(1300, 2000, "bbbbb")];
  const chunks = chunkCues(cues);
  assert.deepEqual(ranges(chunks), [[0, 3]]);
  assert.equal(chunks[0].text, "aaaaa bbbbb");

  const result = redistribute("bonjour monde", chunks[0], cues, "fr");
  assert.equal(result.usedSourceFallback, false);
  assert.deepEqual(texts(result), ["bonjour", "monde"]);
  assert.deepEqual(result.cues.map((c) => c.startMs), [0, 1300]);
  assert.deepEqual(result.cues.map((c) => c.endMs), [1200, 2000]);
});

test("single-cue chunk identity", () => {
  const cues = [cue(500, 1500, "hola")];
  const result = redistribute("hello", { start: 0, end: 1, text: "hola" }, cues, "en");
  assert.equal(result.usedSourceFallback, false);
  assert.equal(result.cues.length, 1);
  assert.equal(result.cues[0].lines[0].text, "hello");
  assert.equal(result.cues[0].startMs, 500);
  assert.equal(result.cues[0].endMs, 1500);
});

test("all-empty translation falls back to source text", () => {
  const cues = [cue(0, 1000, "foo"), cue(1100, 2000, "bar")];
  const result = redistribute("  ​", { start: 0, end: 2, text: "foo bar" }, cues, "en");
  assert.equal(result.usedSourceFallback, true);
  assert.deepEqual(texts(result), ["foo", "bar"]);
  assert.deepEqual(result.cues.map((c) => c.startMs), [0, 1100]);
  assert.deepEqual(result.cues.map((c) => c.endMs), [1000, 2000]);
});

test("speaker prefix reattached verbatim", () => {
  const cues = [
    cue(0, 1000, "Bob: hi there", "Bob: "),
    cue(1100, 2000, "friend"),
  ];
  const result = redistribute("salut mon ami", { start: 0, end: 2, text: "hi there friend" }, cues, "fr");
  assert.equal(result.usedSourceFallback, false);
  assert.deepEqual(texts(result), ["Bob: salut", "mon ami"]);
  assert.equal(result.cues[0].lines[0].speakerPrefix, "Bob: ");
  assert.equal(result.cues[1].lines[0].speakerPrefix, null);
});

// Weights count grapheme clusters excluding Cf format characters: a cue of
// "a" + three LRMs weighs 1, not 4. With Cf excluded the split lands after
// "no"; counted, it would land after "way".
test("weights exclude format characters", () => {
  const cues = [cue(0, 1000, "a‎‎‎"), cue(1100, 2000, "bcd")];
  const result = redistribute(
    "no way yes sir",
    { start: 0, end: 2, text: "a‎‎‎ bcd" },
    cues,
    "en"
  );
  assert.deepEqual(texts(result), ["no", "way yes sir"]);
});

// ---------------------------------------------------------------------------
// Output naming
// ---------------------------------------------------------------------------

test("strippedBaseName removes one trailing language code", () => {
  assert.equal(strippedBaseName("Talk.en.vtt"), "Talk");
  assert.equal(strippedBaseName("Movie.zh-Hans.srt"), "Movie");
  assert.equal(strippedBaseName("Video.en-orig.vtt"), "Video");
});

test("strippedBaseName leaves non-language tokens", () => {
  assert.equal(strippedBaseName("Talk.part2.vtt"), "Talk.part2");
  assert.equal(strippedBaseName("Talk.vtt"), "Talk");
  assert.equal(strippedBaseName("archive.backup.srt"), "archive.backup");
});

test("caption output name uses stripped base plus language and container", () => {
  assert.equal(captionOutputName("Talk.en.vtt", "fr", "vtt"), "Talk.fr.vtt");
  assert.equal(captionOutputName("Talk.en.vtt", "en", "txt"), "Talk.en.txt");
});
