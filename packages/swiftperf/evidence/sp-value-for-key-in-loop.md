# sp-value-for-key-in-loop — measured, still hint

## Status
**hint**. Wall-clock JSONL: [sp-value-for-key-in-loop.jsonl](sp-value-for-key-in-loop.jsonl). Not corpus-triaged. The 2026-10-22 corpus verdict does not cover this slug.

## Measurement
`value(forKey:)` every iteration versus reading the property. 200000 ops. The result is kept.

| role | case | median_ms | ops | ratio |
| --- | --- | ---: | ---: | ---: |
| after | `direct_field` | 0.661 | 200000 | 1 |
| before | `value_for_key_each` | 23.258 | 200000 | 35.185 |

A name that changes every iteration cannot become a direct field. Default stays **hint**. This ratio is not a general speedup.

## Unblock
Do not set the default to `error` from this file alone. A changing input, a cold path, or another ABI can erase the difference. Corpus triage is still required before any default change.
