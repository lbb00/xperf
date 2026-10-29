# cs-format-hot — measured, still hint

## Status

**hint**. Wall-clock JSONL: [cs-format-hot.jsonl](cs-format-hot.jsonl). Not corpus-triaged. The 2026-10-22 corpus verdict does not cover this slug.

## Measurement

50000 iterations. Before calls `string.Format` for the loop index; after calls `Int32.ToString`. Both allocate a string. .NET **10.0.13**, linux x64, load 0.08. The first three `ToString` samples were 0.49–0.69 ms and the rest sat near 0.29 ms; the median is 0.3132 ms. `Format` samples were 1.53–1.59 ms. The earlier .NET 8 pair was about 13.7×.

| role | case | median_ms | ops | ratio |
|------|------|----------:|----:|------:|
| after | `tostring` | 0.3132 | 50000 | 1 |
| before | `format_each_iter` | 1.565 | 50000 | 4.997 |

The microbench shows a cost for this one shape. Default stays **hint** until the shape is corpus-triaged. This ratio is not a general speedup.

## Unblock

Do not set the default to `error` from this file alone. A changing input, a cold path, or another ABI can erase the difference. Corpus triage is still required before any default change.
