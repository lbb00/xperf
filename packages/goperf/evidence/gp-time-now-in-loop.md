# gp-time-now-in-loop — measured, still hint

## Status
**hint**. Wall-clock JSONL: [gp-time-now-in-loop.jsonl](gp-time-now-in-loop.jsonl). Not corpus-triaged. The 2026-10-22 corpus verdict does not cover this slug.

## Measurement
`time.Now` every iteration versus one sample. This is not the removed `time.Parse` rule.

| role | case | median_ms | ops | ratio |
| --- | --- | ---: | ---: | ---: |
| after | `sample_once` | 0.078625 | 100000 | 1 |
| before | `sample_each_iter` | 3.337792 | 100000 | 42.452 |

go1.27.3, 2026-10-23. Warm 3, median of 9.

After samples once and does not read the clock inside the loop. Code that needs a fresh timestamp every pass has nothing to hoist. Default stays **hint**. This ratio is not a general speedup.

## Unblock
Do not set the default to `error` from this file alone. A changing input, a cold path, or another ABI can erase the difference. Corpus triage is still required before any default change.
