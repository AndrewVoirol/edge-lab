# Benchmark methodology

Edge Lab’s experiment matrix is a **lab instrument**: fixed presets, exported settings, reproducible JSON. You do not need Google’s closed AI Edge Gallery app to interpret results.

## Configuration

| Parameter | Value |
|-----------|--------|
| Decode cap | 256 tokens (hard stop in stream loop) |
| Warmup | One `"Hi"` turn (turn 1 — primes `BenchmarkInfo`) |
| Benchmark | Same session as warmup (turn 2 — **no** reset between warmup and benchmark) |
| SDK | LiteRT-LM **v0.12.0** (SPM revision `aeefa9b`) |
| Benchmark flag | `ExperimentalFlags.enableBenchmark = true` |

## Per-preset flow

1. **One model load per backend group** — Greedy + Sampled GPU share one load; Greedy + Sampled CPU share another. Only sampler changes between paired presets.
2. When the backend group changes, initialize GPU or CPU (CPU presets use `forceCPU`).
3. Warmup on the current session.
4. Benchmark on the **same** session.
5. Stream the fixed prefill prompt; stop after 256 decode tokens.
6. Read `BenchmarkInfo`, thermal, and memory snapshots into the manifest.

## Presets (UI labels)

| UI label | `preset_id` | Sampler | Backend |
|----------|-------------|---------|---------|
| Greedy GPU | `gallery_greedy_gpu` | topK=1 | GPU |
| Sampled GPU | `sdk_default_gpu` | topK=64, topP=0.95 | GPU |
| Greedy CPU | `cpu_greedy` | topK=1 | CPU |
| Sampled CPU | `cpu_sampled` | topK=64, topP=0.95 | CPU |

Legacy IDs keep schema compatibility; labels describe **what ran**, not a closed app.

## Verifying GPU vs CPU

Trust the manifest, not vibes:

| Signal | Real GPU | Real CPU | CPU preset, GPU fallback |
|--------|----------|----------|---------------------------|
| `requested_backend` | gpu | cpu | cpu |
| `backend` | gpu | cpu | gpu |
| `did_fallback` | false | false | **true** |
| Decode tok/s (typical) | tens+ | ~single digits | GPU-class speed |
| Wall clock (256 decode) | ~7–15 s warm | ~50–60 s | GPU-class |

Xcode logs should show `MainExecutorSettings: backend: GPU` or `CPU` for the active group. `SessionBasic::CancelProcess` after warmup is expected (token cap).

## Sampler / Metal notes

You may see `Metal sampler not available, falling back to statically linked C API` in logs. That affects **how** tokens are sampled on GPU, not whether the GPU backend is active. Greedy (topK=1) and sampled (topK=64) can therefore differ in decode tok/s even on the same GPU load.

## Artisan / web `.litertlm` models

Some bundles (e.g. `gemma-4-E2B-it-web.litertlm`) only ship **GPU_ARTISAN** weights. CPU init may fail with `TF_LITE_PREFILL_DECODE not found`; Edge Lab falls back to GPU (`did_fallback: true`). Compare CPU presets on models that include CPU sections (e.g. `gemma-4-E2B-it.litertlm`).

## Caveats

- Numbers vary with thermal state, background apps, and iOS version.
- `init_time_seconds` reflects engine load (dominant on first GPU preset); use `wall_clock_seconds` for per-preset duration.
- Re-run when comparing SDK or model updates; attach exported JSON for issues.

## Thinking / reasoning models

LiteRT-LM v0.12.0 Swift APIs used by Edge Lab do not expose a separate thinking toggle. If Google adds one, Edge Lab can add a preset in a future release.