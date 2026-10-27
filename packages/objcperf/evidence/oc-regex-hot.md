# oc-regex-hot — measured, still hint

## Status

**hint**. Wall-clock JSONL: [oc-regex-hot.jsonl](oc-regex-hot.jsonl). Not corpus-triaged. The 2026-10-22 corpus verdict does not cover this slug.

## Measurement

2000 matches of a fixed string. Before builds NSRegularExpression each iteration; after builds it once.

| role | case | median_ms | ops | ratio |
|------|------|----------:|----:|------:|
| after | `regex_once` | 0.555000 | 2000 | 1 |
| before | `regex_each_iter` | 8.290000 | 2000 | 14.937 |

The microbench shows a cost for this one shape. Default stays **hint** until the shape is corpus-triaged. This ratio is not a general speedup.

## Unblock

Do not set the default to `error` from this file alone. A changing input, a cold path, or another ABI can erase the difference. Corpus triage is still required before any default change.
