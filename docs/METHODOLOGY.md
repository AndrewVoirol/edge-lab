# Benchmark methodology

Edge Lab’s experiment matrix is designed for **reproducible, shareable** on-device runs.

## Configuration

| Parameter | Value |
|-----------|--------|
| Decode cap | 256 tokens (hard stop in stream loop) |
| Warmup | One `"Hi"` turn, then `resetConversation()` |
| Benchmark turn | Fixed long prefill prompt (~256 tokens) |
| SDK | LiteRT-LM **v0.12.0** |
| Benchmark flag | `ExperimentalFlags.enableBenchmark = true` |

## Per-preset flow

1. **One model load per backend group** — GPU presets 1–2 share a single load; CPU presets 3–4 share another. Only sampler settings change between paired presets (faster, fairer comparisons).
2. Apply preset sampler (topK / topP / temperature) and `resetConversation()`.
3. Initialize backend (GPU preferred; CPU forced for CPU presets; fallback on failure) when the backend group changes.
4. **Warmup** on the current session (turn 1 — primes `BenchmarkInfo`).
5. **Benchmark on the same session** (turn 2 — do not reset between warmup and benchmark).
6. Stream benchmark prompt; stop after 256 tokens.
7. Read `BenchmarkInfo` and device thermal/memory snapshots.

## Presets

- **Gallery greedy** — topK=1, GPU: comparable culture to AI Edge Gallery greedy benches.
- **SDK default** — topK=64, topP=0.95: typical LiteRT-LM sampling defaults.
- **CPU baseline / CPU sampled** — same samplers on CPU backend.

## Caveats

- Numbers vary with thermal state, background apps, and iOS version.
- Re-run matrix when comparing SDK or model updates; attach exported JSON for issues.
- Gallery iOS source is not public; Edge Lab does not claim byte-for-byte parity with their internal build.

## Thinking / reasoning models

LiteRT-LM **v0.12.0** Swift APIs used by Edge Lab do not expose a separate “thinking” or chain-of-thought toggle. If Google adds thinking-mode controls to `ConversationConfig` or sampler APIs, Edge Lab can add a matrix preset in a future release. Until then, document model-specific thinking behavior in your published manifest notes.