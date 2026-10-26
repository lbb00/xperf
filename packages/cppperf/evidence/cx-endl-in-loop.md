# cx-endl-in-loop — measured, still hint

## Status
**hint**. Wall-clock JSONL: [cx-endl-in-loop.jsonl](cx-endl-in-loop.jsonl). Not corpus-triaged. The 2026-10-22 corpus verdict does not cover this slug. Two shapes are in the JSONL.

## Measurement
Both sides write the same integers. On `cout` tied to `/dev/null`, `endl` flushes every insertion. On a string stream, `endl` does not flush a file.

| role | case | median_ms | ops | ratio |
| --- | --- | ---: | ---: | ---: |
| after | newline on cout, one flush | 1.022 | 20000 | 1 |
| before | `endl` on cout | 23.128 | 20000 | 22.622 |
| after | newline on a string stream | 3.923 | 50000 | 1 |
| before | `endl` on a string stream | 3.397 | 50000 | 0.866 |

The external-stream flush shows a cost. The string-stream shape does not (about 0.87×). Default stays hint.

## Unblock
Do not set the default to `error` from this file alone. Another input or a cold path can erase the difference. Corpus triage is still required before any default change.
