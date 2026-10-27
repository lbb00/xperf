# gp-regexp-compile-hot — measured, still hint

## Status

**hint**. Wall-clock JSONL: [gp-regexp-compile-hot.jsonl](gp-regexp-compile-hot.jsonl). Not corpus-triaged. The 2026-10-22 corpus verdict does not cover this slug.

## Measurement

2000 matches of a fixed string. Before regexp.MustCompile each iteration; after compiles once.

| role | case | median_ms | ops | ratio |
|------|------|----------:|----:|------:|
| after | `compile_once` | 0.076459 | 2000 | 1 |
| before | `compile_each_iter` | 0.858166 | 2000 | 11.224 |

go1.27.3, 2026-10-23. Warm 3, median of 9.

The microbench shows a cost for this one shape. Default stays **hint** until the shape is corpus-triaged. This ratio is not a general speedup.

## Unblock

Do not set the default to `error` from this file alone. A changing input, a cold path, or another ABI can erase the difference. Corpus triage is still required before any default change.
