# pp-json-hot — measured, still hint

## Status

**hint**. Wall-clock JSONL: [pp-json-hot.jsonl](pp-json-hot.jsonl). Not corpus-triaged. The 2026-10-22 corpus verdict does not cover this slug.

## Measurement

20000 loads of one fixed JSON object. After parses once and rereads the field. A payload that changes every iteration cannot use this after shape.

| role | case | median_ms | ops | ratio |
|------|------|----------:|----:|------:|
| after | `loads_once` | 0.699000 | 20000 | 1 |
| before | `loads_each_iter` | 20.000584 | 20000 | 28.613 |

CPython 3.15.1, 2026-10-23. Warm 3, median of 9. After parses once and rereads the field.

The microbench shows a cost for this one shape. Default stays **hint** until the shape is corpus-triaged. This ratio is not a general speedup.

## Unblock

Do not set the default to `error` from this file alone. A changing input, a cold path, or another ABI can erase the difference. Corpus triage is still required before any default change.
