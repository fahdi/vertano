// StenoDrop web worker, model load + inference, off the main thread.
//
// Engine: @huggingface/transformers (Transformers.js v4), ONNX Runtime Web.
// Models: the onnx-community multilingual Whisper builds maintained by the
// Transformers.js team for browser use (same family as Hugging Face's own
// official whisper-webgpu / whisper-word-timestamps example apps). The app
// offers three quality tiers for offline mode; the mapping to model IDs
// lives here and is never shown to users (capability framing, not
// filenames). WebGPU device with mixed dtypes (fp32 encoder / q4 decoder)
// when available, falling back to wasm with q8 dtype otherwise.
//
// Note: onnx-community/whisper-small-ONNX (a separate, newer export) fails
// under transformers.js 4.2.0 with "Missing the following inputs:
// cache_position" regardless of decoder dtype (q4/uint8/int8 all fail
// identically), reproducing a known open compatibility issue
// (huggingface/transformers.js#1707). The Enhanced tier therefore uses
// onnx-community/whisper-small, the same-generation export as whisper-base,
// which does not carry the cache_position input.
import { pipeline } from "https://cdn.jsdelivr.net/npm/@huggingface/transformers@4.2.0";

// Offline quality tiers -> model IDs. Cloud mode is the Maximum tier and
// never reaches this worker.
const TIER_MODELS = {
  efficient: "onnx-community/whisper-tiny",
  standard: "onnx-community/whisper-base",
  enhanced: "onnx-community/whisper-small",
};
const DEFAULT_TIER = "standard";

const PER_DEVICE_CONFIG = {
  webgpu: {
    device: "webgpu",
    dtype: {
      encoder_model: "fp32",
      decoder_model_merged: "q4",
    },
  },
  wasm: {
    device: "wasm",
    dtype: "q8",
  },
};

// One transcriber per tier: Transformers.js caches the downloaded weights in
// the browser's Cache Storage, so switching tiers re-downloads nothing that
// was fetched before, and switching back is instant.
const transcribers = new Map();
let devicePromise = null;
let activeDevice = null;

async function detectDevice() {
  if (devicePromise) return devicePromise;
  devicePromise = (async () => {
    let device = "wasm";
    try {
      if (navigator.gpu) {
        const adapter = await navigator.gpu.requestAdapter();
        if (adapter) device = "webgpu";
      }
    } catch {
      device = "wasm";
    }
    activeDevice = device;
    self.postMessage({ type: "device", device });
    return device;
  })();
  return devicePromise;
}

function resolveTier(tier) {
  return TIER_MODELS[tier] ? tier : DEFAULT_TIER;
}

function getTranscriber(tier) {
  const resolved = resolveTier(tier);
  if (transcribers.has(resolved)) return transcribers.get(resolved);

  const promise = (async () => {
    const device = await detectDevice();
    const transcriber = await pipeline("automatic-speech-recognition", TIER_MODELS[resolved], {
      ...PER_DEVICE_CONFIG[device],
      progress_callback: (progress) => {
        self.postMessage({ type: "progress", tier: resolved, progress });
      },
    });
    self.postMessage({ type: "ready", tier: resolved, device });
    return transcriber;
  })();

  transcribers.set(resolved, promise);
  // A failed load (offline mid-download, CDN hiccup) must not poison the
  // cache entry forever; drop it so a retry can start fresh.
  promise.catch(() => {
    if (transcribers.get(resolved) === promise) transcribers.delete(resolved);
  });
  return promise;
}

/** Run one Whisper inference pass and return the flattened text. */
async function runInference(transcriber, audio, language, task) {
  // chunk_length_s/stride_length_s are only needed for audio longer than
  // Whisper's native 30s window; only pass them when the clip actually
  // exceeds that, so short clips take the plain (non-chunked) path.
  const durationSeconds = audio.length / 16000;
  const chunkOpts =
    durationSeconds > 30 ? { chunk_length_s: 30, stride_length_s: 5 } : {};

  const result = await transcriber(audio, {
    language: language === "auto" ? null : language,
    task,
    ...chunkOpts,
  });

  const text = Array.isArray(result) ? result.map((r) => r.text).join(" ") : result.text;
  return (text || "").trim();
}

self.onmessage = async (event) => {
  const msg = event.data;
  if (!msg) return;

  if (msg.type === "warm") {
    // Start (or resume) downloading the requested tier's model so it is
    // ready by the time the first file lands.
    getTranscriber(msg.tier).catch((err) => {
      self.postMessage({
        type: "error",
        jobId: null,
        tier: resolveTier(msg.tier),
        error: String(err && err.message ? err.message : err),
      });
    });
    return;
  }

  if (msg.type !== "transcribe") return;

  // `outputs` is which transcript variants the caller wants back:
  // "original" -> Whisper's plain "transcribe" task (spoken language, untranslated)
  // "english"  -> Whisper's "translate" task (always translates into English)
  // Whisper cannot target any other output language, so these two tasks are
  // the only ones that ever exist here. Translation into other languages
  // happens on the main thread via the browser's built-in Translator API;
  // the "english" task remains as the fallback for browsers without it.
  // When both are requested we simply run the pipeline twice over the same
  // decoded audio, once per task.
  const { jobId, audio, language, outputs, tier } = msg;
  const wantOriginal = !outputs || outputs.includes("original");
  const wantEnglish = !!(outputs && outputs.includes("english"));

  try {
    const transcriber = await getTranscriber(tier);
    const texts = {};

    if (wantOriginal) {
      texts.original = await runInference(transcriber, audio, language, "transcribe");
    }
    if (wantEnglish) {
      texts.english = await runInference(transcriber, audio, language, "translate");
    }

    self.postMessage({
      type: "done",
      jobId,
      texts,
      device: activeDevice,
    });
  } catch (err) {
    self.postMessage({
      type: "error",
      jobId,
      error: String(err && err.message ? err.message : err),
    });
  }
};
