# zp-open-file-in-loop — measured, still hint

## Status
**hint**. Wall-clock JSONL: [zp-open-file-in-loop.jsonl](zp-open-file-in-loop.jsonl). Not corpus-triaged. The 2026-10-22 corpus verdict does not cover this slug.

## Measurement
`Io.Dir.openFileAbsolute` of one one-byte file, 2000 times, versus opening once. The result is kept so the after loop is not deleted.

| role | case | median_ms | ops | ratio |
| --- | --- | ---: | ---: | ---: |
| after | `open_once` | 0.006 | 2000 | 1 |
| before | `open_each_iter` | 13.072 | 2000 | 2134.204 |

A path that changes every iteration cannot be hoisted. A loop that needs a fresh timestamp has nothing to hoist. Default stays **hint**. This ratio is not a general speedup.

## Unblock
Do not set the default to `error` from this file alone. A changing input, a cold path, or another ABI can erase the difference. Corpus triage is still required before any default change.
