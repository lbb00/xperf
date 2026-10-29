# oc-file-read-hot — measured, still hint

## Status
**hint**. Wall-clock JSONL: [oc-file-read-hot.jsonl](oc-file-read-hot.jsonl). Not corpus-triaged. The 2026-10-22 corpus verdict does not cover this slug.

## Measurement
`stringWithContentsOfFile:` of one one-byte file, 500 times, versus reading once.

| role | case | median_ms | ops | ratio |
| --- | --- | ---: | ---: | ---: |
| after | `read_once` | 0.007 | 500 | 1 |
| before | `read_each_iter` | 3.184 | 500 | 449.707 |

The bench reopens one one-byte file. A path that changes every iteration cannot be hoisted; the measured cost is the open and read. Default stays **hint**. This ratio is not a general speedup.

## Unblock
Do not set the default to `error` from this file alone. A changing input, a cold path, or another ABI can erase the difference. Corpus triage is still required before any default change.
