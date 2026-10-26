# gp-os-open-in-loop — measured, still hint

## Status
**hint**. Wall-clock JSONL: [gp-os-open-in-loop.jsonl](gp-os-open-in-loop.jsonl). Not corpus-triaged. The 2026-10-22 corpus verdict does not cover this slug.

## Measurement
`os.Open` plus a short read of one one-byte file, 2000 times, versus opening once.

| role | case | median_ms | ops | ratio |
| --- | --- | ---: | ---: | ---: |
| after | `open_once` | 0.031917 | 2000 | 1 |
| before | `open_each_iter` | 14.717375 | 2000 | 461.114 |

go1.27.3, 2026-10-23. Warm 3, median of 9. After opens and reads once.

The bench reopens one one-byte file. A path that changes every iteration cannot be hoisted; the measured cost is the open and read. Default stays **hint**. This ratio is not a general speedup.

## Unblock
Do not set the default to `error` from this file alone. A changing input, a cold path, or another ABI can erase the difference. Corpus triage is still required before any default change.
