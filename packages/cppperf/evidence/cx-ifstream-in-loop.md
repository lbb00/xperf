# cx-ifstream-in-loop — measured, still hint

## Status
**hint**. Wall-clock JSONL: [cx-ifstream-in-loop.jsonl](cx-ifstream-in-loop.jsonl). Not corpus-triaged. The 2026-10-22 corpus verdict does not cover this slug.

## Measurement
`std::ifstream` of one one-byte file, 2000 times, versus opening once. Both sides read one byte. This does not revive removed CX003.

| role | case | median_ms | ops | ratio |
| --- | --- | ---: | ---: | ---: |
| after | `open_once` | 0.00725 | 2000 | 1 |
| before | `open_each_iter` | 14.6835 | 2000 | 2025.32 |

The bench reopens one one-byte file. A path that changes every iteration cannot be hoisted. Default stays **hint**. This ratio is not a general speedup.

## Unblock
Do not set the default to `error` from this file alone. A changing input, a cold path, or another ABI can erase the difference. Corpus triage is still required before any default change.
