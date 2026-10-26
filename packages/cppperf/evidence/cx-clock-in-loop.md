# cx-clock-in-loop — measured, still hint

## Status
**hint**. Wall-clock JSONL: [cx-clock-in-loop.jsonl](cx-clock-in-loop.jsonl). Not corpus-triaged. The 2026-10-22 corpus verdict does not cover this slug.

## Measurement
Before reads `steady_clock::now` every iteration. After reads it once and does not sample inside the loop.

| role | case | median_ms | ops | ratio |
| --- | --- | ---: | ---: | ---: |
| after | sample once | 0.013 | 100000 | 1 |
| before | sample every iteration | 1.974 | 100000 | 147.117 |

Code that needs a fresh timestamp every pass has nothing to hoist. Default stays hint.

## Unblock
Do not set the default to `error` from this file alone. Another input or a cold path can erase the difference. Corpus triage is still required before any default change.
