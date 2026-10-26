# sp-clock-in-loop — measured, still hint

## Status
**hint**. Wall-clock JSONL: [sp-clock-in-loop.jsonl](sp-clock-in-loop.jsonl). Not corpus-triaged. The 2026-10-22 corpus verdict does not cover this slug.

## Measurement
`Date()` every iteration versus one sample. The result is kept so the after loop is not deleted. `DateFormatter` is a different rule.

| role | case | median_ms | ops | ratio |
| --- | --- | ---: | ---: | ---: |
| after | `sample_once` | 0.008 | 100000 | 1 |
| before | `sample_each_iter` | 1.946 | 100000 | 243.642 |

After samples once and does not construct the date inside the loop. Code that needs a fresh timestamp every pass has nothing to hoist. Default stays **hint**. This ratio is not a general speedup.

## Unblock
Do not set the default to `error` from this file alone. A changing input, a cold path, or another ABI can erase the difference. Corpus triage is still required before any default change.
