# cx-sstream-in-loop — measured, still hint

## Status

**hint**. Wall-clock JSONL: [cx-sstream-in-loop.jsonl](cx-sstream-in-loop.jsonl). Not corpus-triaged. The 2026-10-22 corpus verdict does not cover this slug.

## Measurement

20000 iterations. Before constructs an ostringstream each iteration; after clears and reuses one stream. Modest difference.

| role | case | median_ms | ops | ratio |
|------|------|----------:|----:|------:|
| after | `reuse_stream` | 1.006000 | 20000 | 1 |
| before | `stream_each_iter` | 1.806000 | 20000 | 1.795 |

The microbench shows a small difference only. Default stays **hint**.

## Unblock

Do not set the default to `error` from this file alone. A changing input, a cold path, or another ABI can erase the difference. Corpus triage is still required before any default change.
