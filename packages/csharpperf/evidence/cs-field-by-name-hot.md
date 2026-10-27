# cs-field-by-name-hot — measured, still hint

## Status
**hint**. Wall-clock JSONL: [cs-field-by-name-hot.jsonl](cs-field-by-name-hot.jsonl). Not corpus-triaged. The 2026-10-22 corpus verdict does not cover this slug.

## Measurement
`typeof(Box).GetField("A").GetValue` every iteration versus reading the field. 20000 ops. .NET **10.0.13**, linux x64, load 0.02. The earlier .NET 8 pair was about 62×. A separate .NET 8 run that called `GetField` once and `GetValue` inside the loop was 0.514 ms; that split was not rerun.

| role | case | median_ms | ops | ratio |
| --- | --- | ---: | ---: | ---: |
| after | `direct_field` | 0.0133 | 20000 | 1 |
| before | `getfield_each` | 0.7084 | 20000 | 53.263 |

A name that changes every iteration cannot become a direct field. Default stays **hint**. This ratio is not a general speedup.

## Unblock
Do not set the default to `error` from this file alone. A changing input, a cold path, or another ABI can erase the difference. Corpus triage is still required before any default change.
