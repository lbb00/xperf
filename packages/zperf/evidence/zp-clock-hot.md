# zp-clock-hot — measured, still hint

## Status
**hint**. Wall-clock JSONL: [zp-clock-hot.jsonl](zp-clock-hot.jsonl). Not corpus-triaged. The 2026-10-22 corpus verdict does not cover this slug.

## Measurement
`Io.Clock.awake.now` every iteration versus one sample. An earlier run that discarded the after result was not kept.

| role | case | median_ms | ops | ratio |
| --- | --- | ---: | ---: | ---: |
| after | `sample_once` | 0.051 | 100000 | 1 |
| before | `sample_each_iter` | 2.128 | 100000 | 41.615 |

A path that changes every iteration cannot be hoisted. A loop that needs a fresh timestamp has nothing to hoist. Default stays **hint**. This ratio is not a general speedup.

## Unblock
Do not set the default to `error` from this file alone. A changing input, a cold path, or another ABI can erase the difference. Corpus triage is still required before any default change.
