# sp-dateformatter-hot — measured, still hint

## Status

**hint**. Wall-clock JSONL: [sp-dateformatter-hot.jsonl](sp-dateformatter-hot.jsonl). Not corpus-triaged. The 2026-10-22 corpus verdict does not cover this slug.

## Measurement

2000 formats of one date. Before constructs DateFormatter each iteration; after reuses one.

| role | case | median_ms | ops | ratio |
|------|------|----------:|----:|------:|
| after | `formatter_once` | 1.482010 | 2000 | 1 |
| before | `formatter_each_iter` | 44.153929 | 2000 | 29.793 |

The microbench shows a cost for this one shape. Default stays **hint** until the shape is corpus-triaged. This ratio is not a general speedup.

## Unblock

Do not set the default to `error` from this file alone. A changing input, a cold path, or another ABI can erase the difference. Corpus triage is still required before any default change.
