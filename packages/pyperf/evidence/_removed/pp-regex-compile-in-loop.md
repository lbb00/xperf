# pp-regex-compile-in-loop — removed

## Status

**removed**. The microbench below is historical. See [pp-regex-compile-in-loop.REMOVED.md](pp-regex-compile-in-loop.REMOVED.md). The slug is not reused. The 2026-10-22 corpus verdict does not cover this slug.

## Measurement

5000 searches of a fixed string. Before re.compile each iteration; after compiles once. On this small pattern the search dominates the compile.

| role | case | median_ms | ops | ratio |
|------|------|----------:|----:|------:|
| after | `compile_once` | 1.633042 | 5000 | 1 |
| before | `compile_each_iter` | 1.987834 | 5000 | 1.217 |

The microbench shows a small difference only. Default stays **hint**.

## Unblock

Do not set the default to `error` from this file alone. A changing input, a cold path, or another ABI can erase the difference. Corpus triage is still required before any default change.
