// Caption parsing, rolling-caption reflow, chunking and redistribution for
// .srt/.vtt files. Dependency-free ES module of pure functions, a direct
// port of the Mac implementation (mac/Sources/StenoDrop/Engine/
// CaptionFile.swift, CaptionPipeline.swift, CaptionChunking.swift). The
// normative rules live in the frozen spec:
// docs/superpowers/specs/2026-07-17-mac-caption-translation-design.md.
//
// Formats are the strings "srt" and "vtt". Cues are plain objects:
//   { startMs, endMs, lines: [{ text, hadInlineTimestamps, speakerPrefix }] }
// Timestamps are integer milliseconds throughout; comma/dot conversion
// between SRT and VTT must never accumulate floating-point drift.

/** Named constant from the spec (section 2): governs run continuity,
 * extension, folding, and the chunking gap boundary, with explicit
 * tolerance for 1 ms rounding seams from comma/dot conversion. */
export const EPSILON_MS = 1000;

const MAX_CHUNK_CHARACTERS = 600;
const MAX_CHUNK_CUES = 20;

/** Map a file extension to a caption format, or null. */
export function formatFromExtension(ext) {
  const lower = String(ext).toLowerCase();
  return lower === "srt" || lower === "vtt" ? lower : null;
}

// ---------------------------------------------------------------------------
// Decode ladder (spec section 1)
// ---------------------------------------------------------------------------

function decodeBytes(data, warnings) {
  const bytes = data instanceof Uint8Array ? data : new Uint8Array(data);
  if (bytes.length >= 2 && bytes[0] === 0xff && bytes[1] === 0xfe) {
    return new TextDecoder("utf-16le").decode(bytes);
  }
  if (bytes.length >= 2 && bytes[0] === 0xfe && bytes[1] === 0xff) {
    return new TextDecoder("utf-16be").decode(bytes);
  }
  try {
    return new TextDecoder("utf-8", { fatal: true }).decode(bytes);
  } catch (e) {
    warnings.push("File was not valid UTF-8, decoded as Windows-1252 instead");
    return new TextDecoder("windows-1252").decode(bytes);
  }
}

// ---------------------------------------------------------------------------
// Parsing
// ---------------------------------------------------------------------------

/**
 * Parse .srt/.vtt bytes into cues. Malformed blocks are skipped and counted
 * (best-effort), never fatal unless nothing parses at all, in which case an
 * Error is thrown so the caller can fail the job instead of writing empty
 * output files.
 *
 * @param {Uint8Array|ArrayBuffer} data
 * @param {"srt"|"vtt"} format
 * @returns {{format:string, cues:Array, language:string|null, warnings:string[], skippedBlockCount:number}}
 */
export function parseCaptions(data, format) {
  const warnings = [];
  let text = decodeBytes(data, warnings);
  if (text.startsWith("﻿")) text = text.slice(1);
  text = text.replace(/\r\n/g, "\n").replace(/\r/g, "\n");

  let blocks = splitBlocks(text);
  let language = null;
  if (format === "vtt" && blocks.length > 0 && isHeaderLine(blocks[0][0], "WEBVTT")) {
    for (const line of blocks[0]) {
      if (line.startsWith("Language:")) {
        const value = line.slice("Language:".length).trim();
        if (value) language = value;
      }
    }
    blocks = blocks.slice(1);
  }

  const cues = [];
  let skipped = 0;
  for (const block of blocks) {
    if (
      format === "vtt" &&
      ["NOTE", "STYLE", "REGION"].some((kw) => isHeaderLine(block[0], kw))
    ) {
      continue;
    }
    const cue = parseCueBlock(block, format);
    if (cue) cues.push(cue);
    else skipped += 1;
  }

  if (cues.length === 0) {
    throw new Error("No usable captions found in this file.");
  }
  if (skipped > 0) {
    warnings.push(`Skipped ${skipped} unparseable block${skipped === 1 ? "" : "s"}`);
  }
  return { format, cues, language, warnings, skippedBlockCount: skipped };
}

/** Blank line means a truly empty line: whitespace-only lines are real cue
 * payload in yt-dlp files (the " " filler line) and must not split. */
function splitBlocks(text) {
  const blocks = [];
  let current = [];
  for (const line of text.split("\n")) {
    if (line === "") {
      if (current.length > 0) {
        blocks.push(current);
        current = [];
      }
    } else {
      current.push(line);
    }
  }
  if (current.length > 0) blocks.push(current);
  return blocks;
}

function isHeaderLine(line, keyword) {
  return (
    line === keyword || line.startsWith(keyword + " ") || line.startsWith(keyword + "\t")
  );
}

/** The timing line must be the block's first or second line (the second when
 * an identifier/index precedes it); scanning deeper would misread prose that
 * happens to contain an arrow. */
function parseCueBlock(block, format) {
  for (let timingIndex = 0; timingIndex < Math.min(2, block.length); timingIndex++) {
    const line = block[timingIndex];
    const arrow = line.indexOf("-->");
    if (arrow === -1) continue;
    const startToken = line.slice(0, arrow).trim();
    const afterArrow = line.slice(arrow + 3).trim();
    const endToken = afterArrow.split(/\s/, 1)[0];
    const startMs = parseTimestamp(startToken, format);
    const endMs = parseTimestamp(endToken, format);
    if (startMs === null || endMs === null) return null;
    const lines = block.slice(timingIndex + 1).map(parseLine);
    return { startMs, endMs, lines };
  }
  return null;
}

// ---------------------------------------------------------------------------
// Timestamps
// ---------------------------------------------------------------------------

/**
 * SRT `HH:MM:SS,mmm` (comma); VTT `(HH:)?MM:SS.mmm` (dot, hours optional,
 * more than 2-digit hours tolerated). Integer milliseconds; rounding, never
 * truncation. Returns null for anything malformed.
 */
export function parseTimestamp(string, format) {
  const separator = format === "srt" ? "," : ".";
  const wrongSeparator = format === "srt" ? "." : ",";
  if (string.includes(wrongSeparator)) return null;
  const sepIndex = string.lastIndexOf(separator);
  if (sepIndex === -1) return null;
  const fraction = string.slice(sepIndex + 1);
  if (!/^[0-9]+$/.test(fraction)) return null;

  const components = string.slice(0, sepIndex).split(":");
  let hours, minutes, seconds;
  if (components.length === 3) {
    hours = asciiInt(components[0]);
    minutes = asciiInt(components[1]);
    seconds = asciiInt(components[2]);
  } else if (components.length === 2 && format === "vtt") {
    hours = 0;
    minutes = asciiInt(components[0]);
    seconds = asciiInt(components[1]);
  } else {
    return null;
  }
  if (hours === null || minutes === null || seconds === null) return null;
  if (minutes >= 60 || seconds >= 60) return null;

  // Rounding, never truncation: fraction digits are a decimal fraction of a
  // second, however many there are.
  const digits = fraction.slice(0, 9);
  let value = 0;
  let denominator = 1;
  for (const character of digits) {
    value = value * 10 + (character.charCodeAt(0) - 48);
    denominator *= 10;
  }
  const ms = Math.floor((value * 1000 + Math.floor(denominator / 2)) / denominator);
  return ((hours * 60 + minutes) * 60 + seconds) * 1000 + ms;
}

export function formatTimestamp(ms, format) {
  const total = Math.max(0, ms);
  const separator = format === "srt" ? "," : ".";
  const pad = (n, w) => String(n).padStart(w, "0");
  return (
    pad(Math.floor(total / 3600000), 2) +
    ":" +
    pad(Math.floor(total / 60000) % 60, 2) +
    ":" +
    pad(Math.floor(total / 1000) % 60, 2) +
    separator +
    pad(total % 1000, 3)
  );
}

function asciiInt(text) {
  return /^[0-9]+$/.test(text) ? parseInt(text, 10) : null;
}

// ---------------------------------------------------------------------------
// Line content
// ---------------------------------------------------------------------------

/** Tag spans are deleted byte-for-byte with no separator insertion and no
 * trimming (yt-dlp splits tags mid-word). Entity decoding runs AFTER tag
 * stripping so `&lt;c&gt;` in content never becomes a tag. */
function parseLine(raw) {
  let stripped = "";
  let hadInlineTimestamps = false;
  let speaker = null;
  let insideRubyAnnotation = false;
  let index = 0;
  while (index < raw.length) {
    const character = raw[index];
    if (character === "<") {
      const close = raw.indexOf(">", index + 1);
      if (close !== -1) {
        const tag = raw.slice(index + 1, close);
        if (/^[0-9]/.test(tag) && tag.includes(":")) {
          hadInlineTimestamps = true;
        } else if (tag === "rt" || tag.startsWith("rt ") || tag.startsWith("rt.")) {
          insideRubyAnnotation = true;
        } else if (tag === "/rt") {
          insideRubyAnnotation = false;
        } else if (
          speaker === null &&
          (tag === "v" || tag.startsWith("v ") || tag.startsWith("v."))
        ) {
          const space = tag.indexOf(" ");
          if (space !== -1) {
            const name = tag.slice(space + 1).trim();
            if (name) speaker = decodeEntities(name);
          }
        }
        index = close + 1;
        continue;
      }
    }
    if (!insideRubyAnnotation) stripped += character;
    index += 1;
  }

  let text = decodeEntities(stripped);
  let speakerPrefix = null;
  if (speaker !== null) {
    speakerPrefix = speaker + ": ";
    text = speakerPrefix + text;
  }
  return { text, hadInlineTimestamps, speakerPrefix };
}

export function decodeEntities(string) {
  if (!string.includes("&")) return string;
  let out = "";
  let index = 0;
  while (index < string.length) {
    if (string[index] === "&") {
      const semicolon = string.indexOf(";", index);
      if (semicolon !== -1 && semicolon - index <= 9) {
        const decoded = decodeEntityBody(string.slice(index + 1, semicolon));
        if (decoded !== null) {
          out += decoded;
          index = semicolon + 1;
          continue;
        }
      }
    }
    out += string[index];
    index += 1;
  }
  return out;
}

function decodeEntityBody(body) {
  switch (body) {
    case "amp": return "&";
    case "lt": return "<";
    case "gt": return ">";
    case "nbsp": return " ";
    case "lrm": return "‎";
    case "rlm": return "‏";
    default: {
      if (body[0] !== "#") return null;
      const numeric = body.slice(1);
      let value;
      if (numeric[0] === "x" || numeric[0] === "X") {
        value = /^[0-9a-fA-F]+$/.test(numeric.slice(1))
          ? parseInt(numeric.slice(1), 16)
          : NaN;
      } else {
        value = /^[0-9]+$/.test(numeric) ? parseInt(numeric, 10) : NaN;
      }
      if (!Number.isInteger(value) || value > 0x10ffff) return null;
      if (value >= 0xd800 && value <= 0xdfff) return null;
      return String.fromCodePoint(value);
    }
  }
}

/** Shared with reflow: a line counts as empty when, after entity decoding,
 * every code point is Unicode whitespace (including U+00A0) or a zero-width
 * format (Cf) character; the yt-dlp filler lines are `&nbsp;` or " ". */
export function isEffectivelyEmpty(text) {
  return /^[\p{White_Space}\p{Cf}]*$/u.test(decodeEntities(text));
}

// ---------------------------------------------------------------------------
// Serialization
// ---------------------------------------------------------------------------

/** Output convention: LF line endings, trailing newline, no BOM. SRT indices
 * regenerated 1..N; VTT re-escapes `&` and `<` in payload. */
export function serializeCaptions(cues, format, language = null) {
  const blocks = [];
  if (format === "srt") {
    cues.forEach((cue, index) => {
      let block = `${index + 1}\n`;
      block += formatTimestamp(cue.startMs, "srt");
      block += " --> ";
      block += formatTimestamp(cue.endMs, "srt");
      for (const line of cue.lines) block += "\n" + line.text;
      blocks.push(block);
    });
  } else {
    let header = "WEBVTT";
    if (language) header += `\nLanguage: ${language}`;
    blocks.push(header);
    for (const cue of cues) {
      let block = formatTimestamp(cue.startMs, "vtt");
      block += " --> ";
      block += formatTimestamp(cue.endMs, "vtt");
      for (const line of cue.lines) block += "\n" + escapeForVTT(line.text);
      blocks.push(block);
    }
  }
  return blocks.join("\n\n") + "\n";
}

function escapeForVTT(text) {
  return text.replace(/&/g, "&amp;").replace(/</g, "&lt;");
}

/** Flattened plain-text adjunct: every non-empty line, one per row. */
export function flattenedText(cues) {
  return cues
    .flatMap((cue) => cue.lines.map((line) => line.text))
    .filter((text) => !isEffectivelyEmpty(text))
    .join("\n");
}

// ---------------------------------------------------------------------------
// Rolling-caption reflow (spec section 2): pure cues -> cues, deterministic.
// Dispatch is structural, never format-named. Dedup/fold/retime apply only
// inside detected rolling runs; everything else passes through unchanged
// modulo section 1's enumerated stripping.
// ---------------------------------------------------------------------------

function contentLines(cue) {
  return cue.lines.map((l) => l.text).filter((t) => !isEffectivelyEmpty(t));
}

/**
 * @param {Array} cues
 * @returns {{cues:Array, runBoundaries:Set<number>}} runBoundaries holds the
 *   indices (into the returned cues) of the first emitted cue of each run,
 *   the strict-superset boundary set chunkCues requires.
 */
export function reflow(cues) {
  if (cues.length <= 1) return { cues, runBoundaries: new Set() };
  const sorted = cues
    .map((cue, offset) => ({ cue, offset }))
    .sort((a, b) => a.cue.startMs - b.cue.startMs || a.offset - b.offset)
    .map((entry) => entry.cue);
  const count = sorted.length;

  // Simultaneous-speaker cues (legal VTT) are transparent: runs continue
  // through them, but their own dedup/fold is skipped.
  const overlapping = new Array(count).fill(false);
  for (let index = 1; index < count; index++) {
    if (sorted[index].startMs < sorted[index - 1].endMs) {
      overlapping[index] = true;
      overlapping[index - 1] = true;
    }
  }

  // The ~10 ms static echo cues of the yt-dlp signature contribute no new
  // content; they are removed for pair counting only ("after static-cue
  // removal"). If no run is detected they pass through.
  const detection = [];
  const isEcho = new Array(count).fill(false);
  for (let index = 0; index < count; index++) {
    if (detection.length > 0) {
      const lastIndex = detection[detection.length - 1];
      const last = sorted[lastIndex];
      const gap = sorted[index].startMs - last.endMs;
      const lastContentList = contentLines(last);
      const lastContent =
        lastContentList.length > 0 ? lastContentList[lastContentList.length - 1] : undefined;
      if (
        gap <= EPSILON_MS + 1 &&
        contentLines(sorted[index]).every((t) => t === lastContent)
      ) {
        isEcho[index] = true;
        continue;
      }
    }
    detection.push(index);
  }

  const runs = detectRuns(sorted, detection, overlapping);
  const runOf = new Array(count).fill(null);
  runs.forEach(([runLow, runHigh], runID) => {
    let low = detection[runLow];
    const high = detection[runHigh];
    // Echo cues contiguous with a run edge are part of its signature (the
    // leading blank static of a yt-dlp file) and join the run.
    while (
      low > 0 &&
      isEcho[low - 1] &&
      sorted[low].startMs - sorted[low - 1].endMs <= EPSILON_MS + 1
    ) {
      low -= 1;
    }
    for (let index = low; index <= high; index++) runOf[index] = runID;
    let next = high + 1;
    while (
      next < count &&
      isEcho[next] &&
      sorted[next].startMs - sorted[next - 1].endMs <= EPSILON_MS + 1
    ) {
      runOf[next] = runID;
      next += 1;
    }
  });

  return emit(sorted, runOf, overlapping);
}

/** At least 3 consecutive line-shift pairs are the run TRIGGER; the run's
 * extent is the maximal contiguous (gap <= epsilon, echo-removed) sequence
 * around them. Mid-run yt-dlp cues legitimately restart with a blank first
 * line (fresh display window) or a one-token untagged new line and must not
 * split the run. Returns [low, high] ranges of detection-list positions. */
function detectRuns(sorted, detection, overlapping) {
  function classify(a, b) {
    if (overlapping[a] || overlapping[b]) return "transparent";
    const cueA = sorted[a];
    const cueB = sorted[b];
    if (cueB.startMs - cueA.endMs > EPSILON_MS + 1) return "broken";
    const contentB = contentLines(cueB);
    const contentA = contentLines(cueA);
    const lastA = contentA.length > 0 ? contentA[contentA.length - 1] : undefined;
    if (
      cueB.lines.length >= 2 &&
      contentB.length >= 2 &&
      lastA !== undefined &&
      contentB[0] === lastA
    ) {
      return "shift";
    }
    return "contiguous";
  }

  const runs = [];
  let blockStart = 0;
  let consecutiveShifts = 0;
  let maxConsecutiveShifts = 0;
  if (detection.length <= 1) return [];
  for (let pair = 0; pair < detection.length - 1; pair++) {
    switch (classify(detection[pair], detection[pair + 1])) {
      case "shift":
        consecutiveShifts += 1;
        maxConsecutiveShifts = Math.max(maxConsecutiveShifts, consecutiveShifts);
        break;
      case "transparent":
        // Simultaneous-speaker pairs neither count nor reset: the run
        // continues through them.
        break;
      case "contiguous":
        consecutiveShifts = 0;
        break;
      case "broken":
        if (maxConsecutiveShifts >= 3) runs.push([blockStart, pair]);
        blockStart = pair + 1;
        consecutiveShifts = 0;
        maxConsecutiveShifts = 0;
        break;
    }
  }
  if (maxConsecutiveShifts >= 3) runs.push([blockStart, detection.length - 1]);
  return runs;
}

function emit(sorted, runOf, overlapping) {
  const out = [];
  const outRun = [];
  const runBoundaries = new Set();
  const seenRuns = new Set();
  // The dedup equality test is gap-independent: a run-initial block's first
  // line is compared against the last GLOBALLY emitted line.
  let lastEmitted = undefined;

  const noteBoundary = (run) => {
    if (!seenRuns.has(run)) {
      seenRuns.add(run);
      runBoundaries.add(out.length);
    }
  };

  for (let index = 0; index < sorted.length; index++) {
    const cue = sorted[index];
    const run = runOf[index];
    if (run === null) {
      out.push(cue);
      outRun.push(null);
      const content = contentLines(cue);
      if (content.length > 0) lastEmitted = content[content.length - 1];
      continue;
    }
    if (overlapping[index]) {
      noteBoundary(run);
      out.push(cue);
      outRun.push(run);
      const content = contentLines(cue);
      if (content.length > 0) lastEmitted = content[content.length - 1];
      continue;
    }
    const kept = [];
    for (const line of cue.lines) {
      if (line.hadInlineTimestamps) {
        kept.push(line);
        if (!isEffectivelyEmpty(line.text)) lastEmitted = line.text;
      } else if (!isEffectivelyEmpty(line.text) && line.text !== lastEmitted) {
        kept.push(line);
        lastEmitted = line.text;
      }
    }
    if (kept.length === 0) {
      // Dropped cue: its range folds into the previous cue only when
      // contiguous (<= epsilon); otherwise it is discarded.
      if (out.length > 0) {
        const previous = out[out.length - 1];
        if (cue.startMs - previous.endMs <= EPSILON_MS + 1 && cue.endMs > previous.endMs) {
          out[out.length - 1] = {
            startMs: previous.startMs,
            endMs: Math.max(previous.startMs, cue.endMs),
            lines: previous.lines,
          };
        }
      }
      continue;
    }
    noteBoundary(run);
    out.push({ startMs: cue.startMs, endMs: Math.max(cue.startMs, cue.endMs), lines: kept });
    outRun.push(run);
  }

  // Within a run a completed line spans to the next emitted cue's start when
  // the gap is <= epsilon; inter-run gaps are preserved untouched.
  for (let index = 0; index < out.length - 1; index++) {
    if (outRun[index] === null || outRun[index + 1] !== outRun[index]) continue;
    const gap = out[index + 1].startMs - out[index].endMs;
    if (gap > 0 && gap <= EPSILON_MS + 1) {
      out[index] = {
        startMs: out[index].startMs,
        endMs: out[index + 1].startMs,
        lines: out[index].lines,
      };
    }
  }
  return { cues: out, runBoundaries };
}

// ---------------------------------------------------------------------------
// Chunking (spec section 5): per-cue translation of 3-8 word rolling
// fragments yields word salad, so cues are merged into sentence-ish chunks
// for the translator and the translated string is split back across the
// member cues by source-length proportion.
// ---------------------------------------------------------------------------

/** A cue's translator-facing text: speaker prefixes stripped, effectively
 * empty lines dropped, remaining lines joined with single spaces. */
function cleanedText(cue) {
  return cue.lines
    .map((line) => {
      let text = line.text;
      if (line.speakerPrefix && text.startsWith(line.speakerPrefix)) {
        text = text.slice(line.speakerPrefix.length);
      }
      return trimEdges(text);
    })
    .filter((text) => text.length > 0)
    .join(" ");
}

/** U+2026 is spec-mandated as a boundary but has Sentence_Terminal=No in the
 * UCD, so it rides alongside the property check. */
function endsAtSentenceBoundary(text) {
  return /[\p{Sentence_Terminal}…]$/u.test(text);
}

function overlapsNeighbor(cues, index) {
  if (index > 0 && cues[index - 1].endMs > cues[index].startMs) return true;
  if (index + 1 < cues.length && cues[index].endMs > cues[index + 1].startMs) return true;
  return false;
}

/**
 * Chunk reflowed cues into translator input strings.
 * @param {Array} cues
 * @param {Set<number>} runBoundaries indices of cues that START a new reflow
 *   run; a chunk never spans one (chunk boundaries are a strict superset of
 *   run boundaries). Cues that time-overlap a neighbor are always solo chunks.
 * @returns {Array<{start:number, end:number, text:string}>} half-open cue
 *   index ranges with the chunk's translator text.
 */
export function chunkCues(cues, runBoundaries = new Set()) {
  const chunks = [];
  let chunkStart = 0;
  let chunkText = "";
  let previousCueText = "";

  const close = (before) => {
    if (before <= chunkStart) return;
    chunks.push({ start: chunkStart, end: before, text: chunkText });
    chunkStart = before;
    chunkText = "";
  };

  for (let index = 0; index < cues.length; index++) {
    const cueText = cleanedText(cues[index]);
    if (index > 0) {
      let boundary =
        runBoundaries.has(index) ||
        cues[index].startMs - cues[index - 1].endMs >= EPSILON_MS ||
        endsAtSentenceBoundary(previousCueText) ||
        overlapsNeighbor(cues, index) ||
        overlapsNeighbor(cues, index - 1);
      if (!boundary && index - chunkStart >= MAX_CHUNK_CUES) {
        boundary = true;
      }
      if (
        !boundary &&
        chunkText.length > 0 &&
        cueText.length > 0 &&
        chunkText.length + 1 + cueText.length > MAX_CHUNK_CHARACTERS
      ) {
        boundary = true;
      }
      if (boundary) close(index);
    }
    if (cueText.length > 0) {
      chunkText = chunkText.length === 0 ? cueText : chunkText + " " + cueText;
    }
    previousCueText = cueText;
  }
  close(cues.length);
  return chunks;
}

// ---------------------------------------------------------------------------
// Redistribution (spec section 5): an algorithm, not an adjective.
// ---------------------------------------------------------------------------

/** Edge trim used everywhere a segment or line becomes cue text: strips
 * whitespace (including U+00A0) and zero-width Cf characters, mirroring
 * isEffectivelyEmpty. */
function trimEdges(text) {
  return text
    .replace(/^[\p{White_Space}\p{Cf}]+/u, "")
    .replace(/[\p{White_Space}\p{Cf}]+$/u, "");
}

/** Grapheme clusters excluding characters that are purely Cf (format):
 * directional marks must not skew the proportions. */
function graphemeWeight(text) {
  let weight = 0;
  for (const { segment } of graphemeSegmenter.segment(text)) {
    if (!/^\p{Cf}+$/u.test(segment)) weight += 1;
  }
  return weight;
}

const graphemeSegmenter = new Intl.Segmenter(undefined, { granularity: "grapheme" });

/** Largest-remainder apportionment of `total` target graphemes across the
 * weights; remainder ties break toward the earlier cue. */
function apportion(total, weights) {
  const weightSum = weights.reduce((a, b) => a + b, 0);
  const counts = weights.map((w) => Math.floor((w * total) / weightSum));
  let leftover = total - counts.reduce((a, b) => a + b, 0);
  const byRemainder = weights
    .map((_, index) => index)
    .sort((a, b) => {
      const left = (weights[a] * total) % weightSum;
      const right = (weights[b] * total) % weightSum;
      return left !== right ? right - left : a - b;
    });
  for (const index of byRemainder) {
    if (leftover <= 0) break;
    counts[index] += 1;
    leftover -= 1;
  }
  return counts;
}

/** Grapheme-offset ranges of word tokens in `text`, segmented with the
 * TARGET language so spaceless scripts (ja/zh/ko/th) segment correctly. Any
 * position strictly inside one is not a legal split point. */
function wordBoundarySplitPositions(graphemes, language) {
  const text = graphemes.join("");
  // Map each grapheme's starting code-unit offset to its grapheme index so
  // word-segment boundaries (which always fall on grapheme boundaries)
  // convert exactly.
  const unitToGrapheme = new Map();
  let unit = 0;
  graphemes.forEach((grapheme, index) => {
    unitToGrapheme.set(unit, index);
    unit += grapheme.length;
  });
  unitToGrapheme.set(unit, graphemes.length);

  let segmenter;
  try {
    segmenter = new Intl.Segmenter(language || undefined, { granularity: "word" });
  } catch (e) {
    segmenter = new Intl.Segmenter(undefined, { granularity: "word" });
  }
  const ranges = [];
  for (const part of segmenter.segment(text)) {
    if (!part.isWordLike) continue;
    const start = unitToGrapheme.get(part.index);
    const end = unitToGrapheme.get(part.index + part.segment.length);
    if (start !== undefined && end !== undefined) ranges.push({ start, end });
  }
  return ranges;
}

/** Positions never index inside a grapheme cluster (they are grapheme
 * offsets); this only moves ones that fall inside a word token, to the
 * nearest token edge, ties toward the earlier one. */
function snap(position, tokens) {
  for (const token of tokens) {
    if (token.start < position && position < token.end) {
      return position - token.start <= token.end - position ? token.start : token.end;
    }
  }
  return position;
}

function translatedCue(member, text) {
  let prefix = null;
  for (const line of member.lines) {
    if (line.speakerPrefix) {
      prefix = line.speakerPrefix;
      break;
    }
  }
  return {
    startMs: member.startMs,
    endMs: member.endMs,
    lines: [
      {
        text: (prefix || "") + text,
        hadInlineTimestamps: false,
        speakerPrefix: prefix,
      },
    ],
  };
}

function sourceFallback(members, cleanedTexts) {
  return {
    cues: members.map((member, index) => translatedCue(member, cleanedTexts[index])),
    usedSourceFallback: true,
  };
}

/**
 * Split `translatedText` back across the chunk's member cues in proportion
 * to their source grapheme weights, snapping each split to a target-language
 * word boundary. Assigns text only: surviving cues keep their source
 * timings, except fold-forward endMs extension over dropped empty cues.
 * `usedSourceFallback: true` signals a chunk whose entire translation came
 * back empty; the cues carry cleaned source text and the caller must attach
 * a visible warning.
 *
 * @param {string} translatedText
 * @param {{start:number, end:number, text:string}} chunk
 * @param {Array} cues the full reflowed cue list the chunk indexes into
 * @param {string|null} targetLanguage BCP-47 code for word segmentation
 * @returns {{cues:Array, usedSourceFallback:boolean}}
 */
export function redistribute(translatedText, chunk, cues, targetLanguage) {
  const members = cues.slice(chunk.start, chunk.end);
  const cleanedTexts = members.map(cleanedText);
  const weights = cleanedTexts.map(graphemeWeight);
  const translated = trimEdges(translatedText);
  const weightSum = weights.reduce((a, b) => a + b, 0);

  if (translated.length === 0 || weightSum === 0) {
    return sourceFallback(members, cleanedTexts);
  }

  const target = Array.from(graphemeSegmenter.segment(translated), (s) => s.segment);
  const counts = apportion(target.length, weights);
  const boundaries = wordBoundarySplitPositions(target, targetLanguage);

  const offsets = [];
  let cumulative = 0;
  for (const count of counts.slice(0, -1)) {
    cumulative += count;
    const snapped = snap(cumulative, boundaries);
    offsets.push(Math.max(snapped, offsets.length > 0 ? offsets[offsets.length - 1] : 0));
  }
  offsets.push(target.length);

  const output = [];
  let segmentStart = 0;
  for (let index = 0; index < members.length; index++) {
    const member = members[index];
    const offset = offsets[index];
    const segment = trimEdges(target.slice(segmentStart, offset).join(""));
    segmentStart = offset;
    if (segment.length === 0) {
      // Fold-forward: the previous survivor absorbs the dropped cue's range;
      // a leading empty cue has nowhere to fold and is discarded outright.
      if (output.length > 0) {
        const previous = output[output.length - 1];
        output[output.length - 1] = {
          startMs: previous.startMs,
          endMs: Math.max(previous.startMs, Math.max(previous.endMs, member.endMs)),
          lines: previous.lines,
        };
      }
      continue;
    }
    output.push(translatedCue(member, segment));
  }

  if (output.length === 0) {
    return sourceFallback(members, cleanedTexts);
  }
  return { cues: output, usedSourceFallback: false };
}

// ---------------------------------------------------------------------------
// Output naming (spec section 8): `<stripped base>.<lang>.<ext>`.
// ---------------------------------------------------------------------------

/** Basename with the container extension removed and one recognized trailing
 * language code stripped (`Talk.en.vtt` -> `Talk`, `Video.en-orig.vtt` ->
 * `Video`); yt-dlp always writes `<name>.<lang>.<ext>`. `Talk.part2` is left
 * alone. */
export function strippedBaseName(fileName) {
  const extDot = fileName.lastIndexOf(".");
  const base = extDot === -1 ? fileName : fileName.slice(0, extDot);
  const dot = base.lastIndexOf(".");
  if (dot <= 0) return base;
  const token = base.slice(dot + 1);
  return isLanguageCodeToken(token) ? base.slice(0, dot) : base;
}

/** A primary language subtag ISO 639 recognizes, optionally followed by
 * 2-8 character alphanumeric subtags (`en`, `zh-Hans`, `en-orig`). */
function isLanguageCodeToken(token) {
  const parts = token.split("-");
  const first = parts[0];
  if (!(first.length >= 2 && first.length <= 3) || !/^[a-zA-Z]+$/.test(first)) return false;
  if (!isISOLanguage(first.toLowerCase())) return false;
  for (const part of parts.slice(1)) {
    if (!(part.length >= 2 && part.length <= 8) || !/^[a-zA-Z0-9]+$/.test(part)) return false;
  }
  return true;
}

let languageDisplayNames = null;

/** ISO 639 recognition via Intl.DisplayNames: known codes resolve to a
 * language name, unknown ones echo back unchanged. */
function isISOLanguage(code) {
  try {
    if (!languageDisplayNames) {
      languageDisplayNames = new Intl.DisplayNames(["en"], { type: "language" });
    }
    const name = languageDisplayNames.of(code);
    return typeof name === "string" && name.toLowerCase() !== code.toLowerCase();
  } catch (e) {
    return false;
  }
}

/** Deterministic caption output name: stripped base + language + extension. */
export function captionOutputName(fileName, language, ext) {
  return `${strippedBaseName(fileName)}.${language}.${ext}`;
}
