# rb-regexp-new-hot — measured, still hint

## Status

**hint**. Wall-clock JSONL: [rb-regexp-new-hot.jsonl](rb-regexp-new-hot.jsonl). Not corpus-triaged. The 2026-10-22 corpus verdict does not cover this slug.

## Measurement

5000 matches of a fixed string. Before Regexp.new each iteration; after compiles once.

| role | case | median_ms | ops | ratio |
|------|------|----------:|----:|------:|
| after | `regexp_once` | 0.565000 | 5000 | 1 |
| before | `regexp_each_iter` | 2.041000 | 5000 | 3.612 |

Ruby 4.0.8, 2026-10-23. Warm 3, median of 9.

The microbench shows a cost for this one shape. Default stays **hint** until the shape is corpus-triaged. This ratio is not a general speedup.

## Unblock

Do not set the default to `error` from this file alone. A changing input, a cold path, or another ABI can erase the difference. Corpus triage is still required before any default change.
