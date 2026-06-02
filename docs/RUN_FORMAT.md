# Run manifest format (`schema_version` 1.1)

Exported after a matrix run via **Share…** or auto-saved to **Files → Edge Lab → EdgeLabRuns**.

## Fields

| Field | Description |
|-------|-------------|
| `schema_version` | `1.1` |
| `matrix_version` | Matrix protocol revision (`"1"`) |
| `run_mode` | `"full"` (256 decode). Future: `"quick"` (32 decode) |
| `decode_cap` | Max decode tokens per preset |
| `wall_clock_seconds` | Per-preset wall time (load + warmup + benchmark) |
| `prefill_token_count` | From LiteRT-LM `BenchmarkInfo` |
| `median_token_latency_ms` | Median inter-token latency during decode |
| `memory_start_mb` / `memory_end_mb` | Available memory snapshot |

## Example

```json
{
  "schema_version": "1.1",
  "app": "edge-lab",
  "app_version": "1.0.0",
  "created_at": "2026-06-02T12:00:00Z",
  "matrix_version": "1",
  "run_mode": "full",
  "device": {
    "model_identifier": "iPhone17,2",
    "marketing_name": "iPhone 16 Pro Max",
    "os_version": "..."
  },
  "model": { "filename": "gemma-4-E2B-it.litertlm" },
  "litert_lm_version": "0.12.0",
  "decode_cap": 256,
  "matrix": [
    {
      "preset_id": "gallery_greedy_gpu",
      "preset_label": "Gallery greedy",
      "backend": "gpu",
      "did_fallback": false,
      "sampler": { "topK": 1, "topP": 1.0, "temperature": 1.0 },
      "metrics": {
        "decode_tokens_per_second": 0.0,
        "prefill_tokens_per_second": 0.0,
        "ttft_seconds": 0.0,
        "init_time_seconds": 0.0,
        "prefill_token_count": 0,
        "decode_tokens": 256,
        "wall_clock_seconds": 0.0,
        "median_token_latency_ms": 0.0,
        "memory_start_mb": 0.0,
        "memory_end_mb": 0.0,
        "thermal_start": "nominal",
        "thermal_end": "fair",
        "memory_delta_mb": 0.0
      }
    }
  ]
}
```

Failed presets include `metrics: null`.

## Share formats

Edge Lab also exports **Markdown** (GitHub gists, blog drafts), **CSV** (Numbers/Sheets), and **tweet text** from the same run.