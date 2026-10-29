# jp-intl-datetimeformat-hot — measured, still hint

## Status
**hint**. Wall-clock JSONL: [jp-intl-datetimeformat-hot.jsonl](jp-intl-datetimeformat-hot.jsonl). Not corpus-triaged. The 2026-10-22 corpus verdict does not cover this slug. Sibling of the Swift and Objective-C date-formatter rules. Both sides still format one Date.

## Measurement
Node **v26.12.1** on linux x64, load 0.74. Harness: `examples/bench/evidence_jp_intl.js`. 2000 dates, locale `en-US`. The earlier Node 24 pair was about 53×.

| role | case | median_ms | ops | ratio |
| --- | --- | ---: | ---: | ---: |
| after | one Intl.DateTimeFormat | 1.999 | 2000 | 1 |
| before | constructed every iteration | 72.002 | 2000 | 36.013 |

`new Date` is not this rule. Default stays hint.

## Matcher

The bench built one unchanged formatter. A locale or options argument that names the loop binding is not reported. Default `--scope all` reports stable formatters outside loops too; `--scope loop` keeps the former in-loop-only match. The hint invites reusing one formatter when locale and options are stable.

## Unblock
Do not set the default to `error` from this file alone. Another input or a cold path can erase the difference. Corpus triage is still required before any default change.
