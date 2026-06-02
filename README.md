# Edge Lab

**On-device experiment matrix for Gemma and LiteRT-LM on iPhone** — bring your `.litertlm` model, tap **Run Experiment Matrix**, export JSON proof.

Google’s [AI Edge Gallery](https://github.com/google-ai-edge/gallery) ships a closed-source iOS app ([source requested](https://github.com/google-ai-edge/gallery/issues/420)). Edge Lab is the open lab for **reproducible benchmarks** on your hardware.

![Edge Lab experiment matrix](docs/images/matrix-screenshot.png)

> Add a screenshot at `docs/images/matrix-screenshot.png` after your first device run.

## Quick start

1. Clone and generate the Xcode project:
   ```bash
   git clone https://github.com/andrewvoirol/edge-lab.git
   cd edge-lab
   tuist generate
   open EdgeLab.xcworkspace
   # Build with pinned SDK (required for LiteRT-LM):
   xcodebuild -workspace EdgeLab.xcworkspace -scheme EdgeLab \
     -onlyUsePackageVersionsFromResolvedFile \
     -destination 'generic/platform=iOS' build
   ```
2. **Bring your model** (`.litertlm`) — see [docs/BYOM.md](docs/BYOM.md).
3. Select a model → **Run Experiment Matrix** → **Export JSON manifest**.

**Tested on:** iPhone 16 Pro Max · LiteRT-LM **v0.12.0** (SPM revision `aeefa9b`) · 256 decode tokens per preset

> **Note:** `EdgeLab.xcworkspace/xcshareddata/swiftpm/Package.resolved` pins LiteRT-LM to a known-good revision. After `tuist generate`, restore or keep that file before building.

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