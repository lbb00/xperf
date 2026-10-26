# rb-json-in-loop — measured, still hint

## Status

**hint**. Wall-clock JSONL: [rb-json-in-loop.jsonl](rb-json-in-loop.jsonl). Not corpus-triaged. The 2026-10-22 corpus verdict does not cover this slug.

## Measurement

20000 parses of one fixed JSON object. After parses once. A changing payload cannot use this after shape.

| role | case | median_ms | ops | ratio |
|------|------|----------:|----:|------:|
| after | `parse_once` | 0.781000 | 20000 | 1 |
| before | `parse_each_iter` | 6.116000 | 20000 | 7.831 |

Ruby 4.0.8, 2026-10-23. Warm 3, median of 9.

The microbench shows a cost for this one shape. Default stays **hint** until the shape is corpus-triaged. This ratio is not a general speedup.

## Unblock

Do not set the default to `error` from this file alone. A changing input, a cold path, or another ABI can erase the difference. Corpus triage is still required before any default change.
