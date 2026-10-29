# cx-regex-ctor-hot — measured, still hint

## Status
**hint**. Wall-clock JSONL: [cx-regex-ctor-hot.jsonl](cx-regex-ctor-hot.jsonl). Not corpus-triaged. The 2026-10-22 corpus verdict does not cover this slug.

## Measurement
Both sides search the short haystack `id-2026`. Before constructs `std::regex` every iteration.

| role | case | median_ms | ops | ratio |
| --- | --- | ---: | ---: | ---: |
| after | construct once | 0.305 | 400 | 1 |
| before | construct every iteration | 2.355 | 400 | 7.725 |

A long haystack hid this constructor (an earlier run was about 1.55×). Default stays hint.

## Unblock
Do not set the default to `error` from this file alone. Another input or a cold path can erase the difference. Corpus triage is still required before any default change.
