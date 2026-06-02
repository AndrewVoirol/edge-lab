# Run manifest format (`schema_version` 1.0)

Exported via **Export JSON manifest** after a matrix run.

```json
{
  "schema_version": "1.0",
  "app": "edge-lab",
  "app_version": "1.0.0",
  "created_at": "ISO-8601",
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
        "decode_tokens": 256,
        "thermal_start": "nominal",
        "thermal_end": "fair",
        "memory_delta_mb": 0.0
      }
    }
  ]
}
```

Failed presets include `metrics: null` (future versions may add `error` field).