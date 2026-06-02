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

1. Load model with preset sampler (topK / topP / temperature).
2. Initialize backend (GPU preferred; CPU forced for CPU presets; fallback on failure).
3. `resetConversation()` on the loaded engine.
4. Warmup inference (primes `BenchmarkInfo` — nil on first turn without warmup).
5. `resetConversation()` again for a clean context.
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