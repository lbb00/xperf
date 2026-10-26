# rb-file-read-in-loop — measured, still hint

## Status
**hint**. Wall-clock JSONL: [rb-file-read-in-loop.jsonl](rb-file-read-in-loop.jsonl). Not corpus-triaged. The 2026-10-22 corpus verdict does not cover this slug.

## Measurement
`File.read` of one one-byte file, 2000 times, versus reading once.

| role | case | median_ms | ops | ratio |
| --- | --- | ---: | ---: | ---: |
| after | `read_once` | 0.076000 | 2000 | 1 |
| before | `read_each_iter` | 18.897000 | 2000 | 248.644 |

Ruby 4.0.8, 2026-10-23. Warm 3, median of 9.

The bench reopens one one-byte file. A path that changes every iteration cannot be hoisted; the measured cost is the open and read. Default stays **hint**. This ratio is not a general speedup.

## Unblock
Do not set the default to `error` from this file alone. A changing input, a cold path, or another ABI can erase the difference. Corpus triage is still required before any default change.
