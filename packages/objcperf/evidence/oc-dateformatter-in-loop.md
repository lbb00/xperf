# oc-dateformatter-in-loop — measured, still hint

## Status

**hint**. Wall-clock JSONL: [oc-dateformatter-in-loop.jsonl](oc-dateformatter-in-loop.jsonl). Not corpus-triaged. The 2026-10-22 corpus verdict does not cover this slug.

## Measurement

2000 formats of one date. Before allocates NSDateFormatter each iteration; after reuses one.

| role | case | median_ms | ops | ratio |
|------|------|----------:|----:|------:|
| after | `formatter_once` | 1.655000 | 2000 | 1 |
| before | `formatter_each_iter` | 50.273000 | 2000 | 30.376 |

The microbench shows a cost for this one shape. Default stays **hint** until the shape is corpus-triaged. This ratio is not a general speedup.

## Unblock

Do not set the default to `error` from this file alone. A changing input, a cold path, or another ABI can erase the difference. Corpus triage is still required before any default change.
