# jp-regex-ctor-hot — measured, still hint

## Status

**hint**. Wall-clock JSONL: [jp-regex-ctor-hot.jsonl](jp-regex-ctor-hot.jsonl). Not corpus-triaged. The 2026-10-22 corpus verdict does not cover this slug.

## Measurement

20000 tests of the fixed string `aaa-bbb` with `new RegExp("a+")`. Node **v26.12.1** on linux x64, load 0.25. Harness: `examples/bench/evidence_jp_regex.js`. The earlier Node 24 pair was about 3.9×.

| role | case | median_ms | ops | ratio |
|------|------|----------:|----:|------:|
| after | `regexp_once` | 0.273718 | 20000 | 1 |
| before | `regexp_each_iter` | 1.213845 | 20000 | 4.435 |

The microbench shows a cost for this one shape. Default stays **hint** until the shape is corpus-triaged. This ratio is not a general speedup.

## Matcher

The bench compiled one fixed pattern. If the argument names a `for` binding (`word`, `parts[i]`, a destructured `{word}`), the checker does not report the call. That pattern changes every iteration, so compiling once does not apply. Default `--scope all` reports stable-pattern `new RegExp` outside loops too; `--scope loop` keeps the former in-loop-only match. The hint invites a literal or one shared compiled pattern when the pattern is stable.

## Unblock

Do not set the default to `error` from this file alone. A changing input, a cold path, or another ABI can erase the difference. Corpus triage is still required before any default change.
