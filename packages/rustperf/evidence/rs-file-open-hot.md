# rs-file-open-hot — measured, still hint

## Status
**hint**. Wall-clock JSONL: [rs-file-open-hot.jsonl](rs-file-open-hot.jsonl). Not corpus-triaged. The 2026-10-22 corpus verdict does not cover this slug.

## Measurement
`File::open` plus a short read of one one-byte file, 2000 times, versus opening once. rustc **1.99.1**, `-C opt-level=3`, linux x64, load 0.59. The earlier 2750× pair was rustc 1.94 (16.615 ms vs 0.006 ms).

| role | case | median_ms | ops | ratio |
| --- | --- | ---: | ---: | ---: |
| after | `open_once` | 0.00478 | 2000 | 1 |
| before | `open_each_iter` | 1.987266 | 2000 | 415.746 |

The bench reopens one one-byte file. A path that changes every iteration cannot be hoisted; the measured cost is the open and read. Default stays **hint**. This ratio is not a general speedup.

## Unblock
Do not set the default to `error` from this file alone. A changing input, a cold path, or another ABI can erase the difference. Corpus triage is still required before any default change.
