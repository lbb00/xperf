# rs-regex-new-in-loop — measured, still hint

## Status
**hint**. Wall-clock JSONL: [rs-regex-new-in-loop.jsonl](rs-regex-new-in-loop.jsonl). Not corpus-triaged. The 2026-10-22 corpus verdict does not cover this slug. Crate `regex` 1.13.1, rustc 1.99.1, `-C opt-level=3`, linux x64, load 0.44. Both sides still call `is_match` on `id-2026`. The earlier 2968× pair was rustc 1.94 and `regex` 1.11.1.

## Measurement
| role | case | median_ms | ops | ratio |
| --- | --- | ---: | ---: | ---: |
| after | `Regex::new` once | 0.133901 | 2000 | 1 |
| before | `Regex::new` every iteration | 128.901984 | 2000 | 962.666 |

The pattern is `([A-Za-z]+)-([0-9]{2,4})`. Default stays hint.

## Unblock
Do not set the default to `error` from this file alone. Another input or a cold path can erase the difference. Corpus triage is still required before any default change.
