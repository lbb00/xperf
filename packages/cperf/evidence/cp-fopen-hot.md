# cp-fopen-hot — measured, still hint

## Status

**hint**. Wall-clock JSONL: [cp-fopen-hot.jsonl](cp-fopen-hot.jsonl). Not corpus-triaged. The 2026-10-22 corpus verdict does not cover this slug.

## Measurement

2000 opens of a one-byte file. After opens once and rewind/fgetc. This is syscall-bound, not a parse benchmark.

| role | case | median_ms | ops | ratio |
|------|------|----------:|----:|------:|
| after | `fopen_once` | 0.068000 | 2000 | 1 |
| before | `fopen_each_iter` | 28.792000 | 2000 | 423.413 |

The microbench shows a cost for this one shape. Default stays **hint** until the shape is corpus-triaged. This ratio is not a general speedup.

## Unblock

Do not set the default to `error` from this file alone. A changing input, a cold path, or another ABI can erase the difference. Corpus triage is still required before any default change.
