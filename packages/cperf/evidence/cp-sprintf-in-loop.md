# cp-sprintf-in-loop — measured, still hint

## Status

**hint**. Wall-clock JSONL: [cp-sprintf-in-loop.jsonl](cp-sprintf-in-loop.jsonl). Not corpus-triaged. The 2026-10-22 corpus verdict does not cover this slug.

## Measurement

100000 iterations at clang -O2. Before calls sprintf into a stack buffer; after writes decimal digits into the same buffer. The input is the loop index.

| role | case | median_ms | ops | ratio |
|------|------|----------:|----:|------:|
| after | `digits_into_buffer` | 0.543000 | 100000 | 1 |
| before | `sprintf_in_loop` | 7.553000 | 100000 | 13.910 |

The microbench shows a cost for this one shape. Default stays **hint** until the shape is corpus-triaged. This ratio is not a general speedup.

## Unblock

Do not set the default to `error` from this file alone. A changing input, a cold path, or another ABI can erase the difference. Corpus triage is still required before any default change.
