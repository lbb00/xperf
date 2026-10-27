# pp-open-hot — measured, still hint

## Status
**hint**. Wall-clock JSONL: [pp-open-hot.jsonl](pp-open-hot.jsonl). Not corpus-triaged. The 2026-10-22 corpus verdict does not cover this slug.

## Measurement
Builtin `open` of one one-byte file, 2000 times, versus opening once.

| role | case | median_ms | ops | ratio |
| --- | --- | ---: | ---: | ---: |
| after | `open_once` | 0.047792 | 2000 | 1 |
| before | `open_each_iter` | 31.169750 | 2000 | 652.193 |

CPython 3.15.1, 2026-10-23. Warm 3, median of 9. The bench reopens one one-byte file.

The bench reopens one one-byte file. A path that changes every iteration cannot be hoisted; the measured cost is the open and read. Default stays **hint**. This ratio is not a general speedup.

## Unblock
Do not set the default to `error` from this file alone. A changing input, a cold path, or another ABI can erase the difference. Corpus triage is still required before any default change.
