# sp-regex-hot — measured, still hint

## Status

**hint**. Wall-clock JSONL: [sp-regex-hot.jsonl](sp-regex-hot.jsonl). Not corpus-triaged. The 2026-10-22 corpus verdict does not cover this slug.

## Measurement

2000 matches of a fixed string. Before constructs NSRegularExpression each iteration; after constructs it once.

| role | case | median_ms | ops | ratio |
|------|------|----------:|----:|------:|
| after | `regex_once` | 0.307918 | 2000 | 1 |
| before | `regex_each_iter` | 5.050063 | 2000 | 16.401 |

The microbench shows a cost for this one shape. Default stays **hint** until the shape is corpus-triaged. This ratio is not a general speedup.

## Unblock

Do not set the default to `error` from this file alone. A changing input, a cold path, or another ABI can erase the difference. Corpus triage is still required before any default change.
