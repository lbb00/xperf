# pp-deepcopy-in-loop — measured, still hint

## Status

**hint**. Wall-clock JSONL: [pp-deepcopy-in-loop.jsonl](pp-deepcopy-in-loop.jsonl). Not corpus-triaged. The 2026-10-22 corpus verdict does not cover this slug.

## Measurement

5000 copies of one small nested dict. After reuses the same object and does not copy.

| role | case | median_ms | ops | ratio |
|------|------|----------:|----:|------:|
| after | `reuse_tree` | 0.154042 | 5000 | 1 |
| before | `deepcopy_each_iter` | 29.745167 | 5000 | 193.098 |

CPython 3.15.1, 2026-10-23. Warm 3, median of 9. After reads the same nested field and does not copy.

The microbench shows a cost for this one shape. Default stays **hint** until the shape is corpus-triaged. This ratio is not a general speedup.

## Unblock

Do not set the default to `error` from this file alone. A changing input, a cold path, or another ABI can erase the difference. Corpus triage is still required before any default change.
