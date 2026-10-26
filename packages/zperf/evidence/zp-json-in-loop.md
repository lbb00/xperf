# zp-json-in-loop — measured, still hint

## Status
**hint**. Wall-clock JSONL: [zp-json-in-loop.jsonl](zp-json-in-loop.jsonl). Not corpus-triaged. The 2026-10-22 corpus verdict does not cover this slug.

## Measurement
`json.parseFromSlice` of one small object, 2000 times, versus parsing once and reading the field. ReleaseFast. The result is kept so the after loop is not deleted.

| role | case | median_ms | ops | ratio |
| --- | --- | ---: | ---: | ---: |
| after | `parse_once` | 0.003 | 2000 | 1 |
| before | `parse_each_iter` | 7.043 | 2000 | 2683.175 |

A payload that changes every iteration cannot be hoisted. Default stays **hint**. This ratio is not a general speedup.

## Unblock
Do not set the default to `error` from this file alone. A changing input, a cold path, or another ABI can erase the difference. Corpus triage is still required before any default change.
