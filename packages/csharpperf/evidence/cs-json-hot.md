# cs-json-hot — measured, still hint

## Status
**hint**. Wall-clock JSONL: [cs-json-hot.jsonl](cs-json-hot.jsonl). Not corpus-triaged. The 2026-10-22 corpus verdict does not cover this slug.

## Measurement
Before deserializes one fixed payload every iteration. After deserializes it once. .NET **10.0.13**, linux x64, load 0.04. The earlier .NET 8 pair was about 1500×. A .NET 8 loop whose JSON number changed took 19.602 ms for the same 20000 ops; that changing-payload shape was not rerun.

| role | case | median_ms | ops | ratio |
| --- | --- | ---: | ---: | ---: |
| after | deserialize once | 0.0139 | 20000 | 1 |
| before | same payload every iteration | 7.9792 | 20000 | 574.043 |

The large ratio holds only while the payload does not change. Default stays hint.

## Unblock
Do not set the default to `error` from this file alone. Another input or a cold path can erase the difference. Corpus triage is still required before any default change.
