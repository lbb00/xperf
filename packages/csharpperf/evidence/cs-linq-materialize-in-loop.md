# cs-linq-materialize-in-loop — measured, still hint

## Status

**hint**. Wall-clock JSONL: [cs-linq-materialize-in-loop.jsonl](cs-linq-materialize-in-loop.jsonl). Not corpus-triaged. The 2026-10-22 corpus verdict does not cover this slug.

## Measurement

20000 iterations over one 32-int array. Before calls `ToList` each iteration; after calls it once. .NET **10.0.13**, linux x64, load 0.04. The earlier .NET 8 pair was about 42×.

| role | case | median_ms | ops | ratio |
|------|------|----------:|----:|------:|
| after | `tolist_once` | 0.0158 | 20000 | 1 |
| before | `tolist_each_iter` | 0.6147 | 20000 | 38.905 |

The microbench shows a cost for this one shape. Default stays **hint** until the shape is corpus-triaged. This ratio is not a general speedup.

## Unblock

Do not set the default to `error` from this file alone. A changing input, a cold path, or another ABI can erase the difference. Corpus triage is still required before any default change.
