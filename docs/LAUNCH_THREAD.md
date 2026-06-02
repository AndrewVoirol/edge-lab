# Launch thread (copy-paste for X)

Generated from `edge-lab-2026-06-02T20-43-00Z.json` (gemma-4-E2B-it.litertlm · iPhone 16 Pro Max).

**Attach in replies:** screenshot `docs/images/matrix-screenshot.png` + JSON from Examples.

---

## POST THIS (no link)

```
Edge Lab — on-device Gemma matrix on iPhone 16 Pro Max

gemma-4-E2B-it.litertlm
GPU peak 39.8 tok/s (Sampled GPU) · CPU peak 4.9 tok/s (Sampled CPU)

BYOM .litertlm · fully local · no cloud · JSON manifest in replies.

Run yours? Tag @AI_Andrew
```

**Image:** attach `matrix-screenshot.png` as a follow-up reply or second image in thread (X UI varies).

---

## REPLY 1 (manifest + context)

```
4 presets — every knob is in the JSON:

• Greedy GPU (topK=1): 14.6 tok/s decode, 10s wall, gpu
• Sampled GPU (topK=64): 39.8 tok/s decode, 7s wall, gpu
• Greedy CPU (topK=1): 4.7 tok/s decode, 52s wall, cpu
• Sampled CPU (topK=64): 4.9 tok/s decode, 60s wall, cpu

Edge Lab is open source. You don't need Google's closed Gallery app to read these numbers — sampler + requested_backend + actual backend are all exported.
```

**Attach:** `Examples/gemma-4-E2B-it_matrix_run.json` (or screenshot of Files export).

---

## REPLY 2 (links)

```
Repo + sample manifests:
https://github.com/AndrewVoirol/edge-lab

Write-up:
https://ableandrew.com
```

---

## Optional reply (web / artisan model)

If you also ran `gemma-4-E2B-it-web.litertlm`, see `Examples/gemma-4-E2B-it-web_matrix_run.json` — CPU presets may show ↺ GPU fallback (artisan-only weights). Screenshot: `matrix-screenshot-web-fallback.png`.