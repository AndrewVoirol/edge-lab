# Edge Lab

**On-device experiment matrix for Gemma and LiteRT-LM on iPhone** — bring your `.litertlm` model, tap **Run Experiment Matrix**, export JSON proof.

Google’s [AI Edge Gallery](https://github.com/google-ai-edge/gallery) ships a closed-source iOS app ([source requested](https://github.com/google-ai-edge/gallery/issues/420)). Edge Lab is the open lab for **reproducible benchmarks** on your hardware.

![Edge Lab experiment matrix](docs/images/matrix-screenshot.png)

> Add a screenshot at `docs/images/matrix-screenshot.png` after your first device run.

## Quick start

1. Clone and set up (resolves LiteRT-LM — **required**):
   ```bash
   git clone https://github.com/andrewvoirol/edge-lab.git
   cd edge-lab
   ./scripts/setup.sh
   open EdgeLab.xcworkspace   # ← workspace, NOT EdgeLab.xcodeproj
   ```

   **If you see `Missing package product 'LiteRTLM'`:** you opened the `.xcodeproj` or packages were not resolved. Run `./scripts/setup.sh` and open **`EdgeLab.xcworkspace`**.
2. **Bring your model** (`.litertlm`) — see [docs/BYOM.md](docs/BYOM.md).
3. Select a model → **Run Experiment Matrix** → **Export JSON manifest**.

**Tested on:** iPhone 16 Pro Max · LiteRT-LM **v0.12.0** (SPM revision `aeefa9b`) · 256 decode tokens per preset

> **Note:** `.package.resolved` pins LiteRT-LM to revision `aeefa9b` (v0.12.0 XCFrameworks). `setup.sh` copies it into the workspace after `tuist generate`.

## What the matrix runs

| Preset | Backend | topK |
|--------|---------|------|
| Gallery greedy | GPU (CPU fallback) | 1 |
| SDK default | GPU | 64 |
| CPU baseline | CPU | 1 |
| CPU sampled | CPU | 64 |

Each preset: conversation reset → warmup → benchmark prompt → **256 decode cap** → capture TTFT, tok/s, thermal. Methodology: [docs/METHODOLOGY.md](docs/METHODOLOGY.md).

## Export format

Share a versioned manifest: [docs/RUN_FORMAT.md](docs/RUN_FORMAT.md). Example: [Examples/sample_matrix_run.json](Examples/sample_matrix_run.json).

## Links

- [LiteRT-LM](https://github.com/google-ai-edge/LiteRT-LM)
- [Gemma 4 E2B (litert-community)](https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm)
- Write-up: [ableandrew.com](https://ableandrew.com)

## License

Apache-2.0 — see [LICENSE](LICENSE).