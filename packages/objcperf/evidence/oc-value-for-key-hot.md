# oc-value-for-key-hot — measured, still hint

## Status
**hint**. Wall-clock JSONL: [oc-value-for-key-hot.jsonl](oc-value-for-key-hot.jsonl). Not corpus-triaged. The 2026-10-22 corpus verdict does not cover this slug.

## Measurement
`valueForKey:` every iteration versus a direct field read. 200000 ops. The direct read is volatile so the after loop stays. An earlier run that printed 0 ms on the after side was discarded.

| role | case | median_ms | ops | ratio |
| --- | --- | ---: | ---: | ---: |
| after | `direct_field` | 0.051 | 200000 | 1 |
| before | `value_for_key_each` | 6.334 | 200000 | 124.145 |

A name that changes every iteration cannot become a direct field. Default stays **hint**. This ratio is not a general speedup.

## Unblock
Do not set the default to `error` from this file alone. A changing input, a cold path, or another ABI can erase the difference. Corpus triage is still required before any default change.
