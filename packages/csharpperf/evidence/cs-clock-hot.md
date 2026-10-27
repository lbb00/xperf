# cs-clock-hot — measured, still hint

## Status
**hint**. Wall-clock JSONL: [cs-clock-hot.jsonl](cs-clock-hot.jsonl). Not corpus-triaged. The 2026-10-22 corpus verdict does not cover this slug.

## Measurement
`Stopwatch.GetTimestamp` every iteration versus one sample. .NET **10.0.13**, linux x64, load 0.09. The earlier .NET 8 pair was about 15×.

| role | case | median_ms | ops | ratio |
| --- | --- | ---: | ---: | ---: |
| after | `sample_once` | 0.0347 | 100000 | 1 |
| before | `sample_each_iter` | 1.2729 | 100000 | 36.683 |

After samples once and does not read the clock inside the loop. Code that needs a fresh timestamp every pass has nothing to hoist. Default stays **hint**. This ratio is not a general speedup.

## Unblock
Do not set the default to `error` from this file alone. A changing input, a cold path, or another ABI can erase the difference. Corpus triage is still required before any default change.
