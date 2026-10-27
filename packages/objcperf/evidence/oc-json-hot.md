# oc-json-hot — measured, still hint

## Status

**hint**. Wall-clock JSONL: [oc-json-hot.jsonl](oc-json-hot.jsonl). Not corpus-triaged. The 2026-10-22 corpus verdict does not cover this slug.

## Measurement

20000 parses of one fixed JSON object. After parses once. A changing payload cannot use this after shape.

| role | case | median_ms | ops | ratio |
|------|------|----------:|----:|------:|
| after | `json_once` | 0.997000 | 20000 | 1 |
| before | `json_each_iter` | 15.723000 | 20000 | 15.770 |

The microbench shows a cost for this one shape. Default stays **hint** until the shape is corpus-triaged. This ratio is not a general speedup.

## Unblock

Do not set the default to `error` from this file alone. A changing input, a cold path, or another ABI can erase the difference. Corpus triage is still required before any default change.
