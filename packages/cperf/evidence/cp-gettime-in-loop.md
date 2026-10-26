# cp-gettime-in-loop — measured, still hint

## Status

**hint**. Wall-clock JSONL: [cp-gettime-in-loop.jsonl](cp-gettime-in-loop.jsonl). Not corpus-triaged. The 2026-10-22 corpus verdict does not cover this slug.

## Measurement

100000 iterations. Both sides store a value each iteration so the loop cannot collapse. Before calls gettimeofday; after uses one sample taken outside the loop.

| role | case | median_ms | ops | ratio |
|------|------|----------:|----:|------:|
| after | `clock_once` | 0.036000 | 100000 | 1 |
| before | `gettimeofday_in_loop` | 1.194000 | 100000 | 33.167 |

The microbench shows a cost for this one shape. Default stays **hint** until the shape is corpus-triaged. This ratio is not a general speedup.

## Unblock

Do not set the default to `error` from this file alone. A changing input, a cold path, or another ABI can erase the difference. Corpus triage is still required before any default change.
