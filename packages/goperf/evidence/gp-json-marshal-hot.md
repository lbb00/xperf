# gp-json-marshal-hot — measured, still hint

## Status

**hint**. Wall-clock JSONL: [gp-json-marshal-hot.jsonl](gp-json-marshal-hot.jsonl). Not corpus-triaged. The 2026-10-22 corpus verdict does not cover this slug.

## Measurement

20000 unmarshals of one fixed JSON object. After unmarshals once. A changing payload cannot use this after shape.

| role | case | median_ms | ops | ratio |
|------|------|----------:|----:|------:|
| after | `unmarshal_once` | 0.007416 | 20000 | 1 |
| before | `unmarshal_each_iter` | 5.870792 | 20000 | 791.639 |

go1.27.3, 2026-10-23. Warm 3, median of 9.

The microbench shows a cost for this one shape. Default stays **hint** until the shape is corpus-triaged. This ratio is not a general speedup.

## Unblock

Do not set the default to `error` from this file alone. A changing input, a cold path, or another ABI can erase the difference. Corpus triage is still required before any default change.
