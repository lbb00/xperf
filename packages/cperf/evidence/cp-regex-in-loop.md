# cp-regex-in-loop — measured, still hint

## Status
**hint**. Wall-clock JSONL: [cp-regex-in-loop.jsonl](cp-regex-in-loop.jsonl). Not corpus-triaged. The 2026-10-22 corpus verdict does not cover this slug. `regexec` is not matched.

## Measurement
Both sides call `regexec` on `id-2026`. Before calls `regcomp` and `regfree` every iteration.

| role | case | median_ms | ops | ratio |
| --- | --- | ---: | ---: | ---: |
| after | compile once | 0.834 | 2000 | 1 |
| before | `regcomp` every iteration | 8.131 | 2000 | 9.749 |

This is the C sibling of the compile-once regular-expression rules. Default stays hint.

## Unblock
Do not set the default to `error` from this file alone. Another input or a cold path can erase the difference. Corpus triage is still required before any default change.
