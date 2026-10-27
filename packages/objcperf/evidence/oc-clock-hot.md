# oc-clock-hot — measured, still hint

## Status
**hint**. Wall-clock JSONL: [oc-clock-hot.jsonl](oc-clock-hot.jsonl). Not corpus-triaged. The 2026-10-22 corpus verdict does not cover this slug.

## Measurement
`[NSDate date]` every iteration versus one sample. The result is kept so the after loop is not deleted. `NSDateFormatter` is a different rule.

| role | case | median_ms | ops | ratio |
| --- | --- | ---: | ---: | ---: |
| after | `sample_once` | 0.004 | 100000 | 1 |
| before | `sample_each_iter` | 3.098 | 100000 | 769.061 |

After samples once and does not construct the date inside the loop. Code that needs a fresh timestamp every pass has nothing to hoist. Default stays **hint**. This ratio is not a general speedup.

## Unblock
Do not set the default to `error` from this file alone. A changing input, a cold path, or another ABI can erase the difference. Corpus triage is still required before any default change.
