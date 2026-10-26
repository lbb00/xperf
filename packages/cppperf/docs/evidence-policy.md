# cppperf evidence policy

## Gate

A rule may be treated as **`error`** only if both exist under `packages/cppperf/evidence/`:

1. `<slug>.md` — claim, how measured, toolchain version, limits
2. `<slug>.jsonl` — ≥1 before/after line with `rule`, `case`, `median_ms`, `ops`, `ratio`, `ts`

Otherwise the rule stays **`hint`**.

## Current map

As of 2026-10-23. The 2026-10-22 corpus verdict does not cover slugs added after that date.

| Rule | Severity | Evidence | Smell |
|------|----------|----------|-------|
| cx-regex-ctor-in-loop | **hint** | measured (`cx-regex-ctor-in-loop.md` + `cx-regex-ctor-in-loop.jsonl`); stay hint | `std::regex` constructed in loop; not corpus-triaged |
| cx-endl-in-loop | **hint** | measured (`cx-endl-in-loop.md` + `cx-endl-in-loop.jsonl`); stay hint | `endl` flush in loop; not corpus-triaged |
| cx-clock-in-loop | **hint** | measured (`cx-clock-in-loop.md` + `cx-clock-in-loop.jsonl`); stay hint | clock sample in a loop; about 147× vs sampling once; not corpus-triaged |
| cx-ifstream-in-loop | **hint** | measured (`cx-ifstream-in-loop.md` + `cx-ifstream-in-loop.jsonl`); stay hint | `ifstream` opened in a loop; same path only; not corpus-triaged |
| cx-const-by-value | **hint** | measured (`cx-const-by-value.md` + `cx-const-by-value.jsonl`); stay hint | `const` string or vector by value (parameter or range-for); about 15–21× when the copy allocates; short strings and full scans stay near 1×; not corpus-triaged |
| cx-vector-bool | **hint** | measured (`cx-vector-bool.md` + `cx-vector-bool.jsonl`); stay hint | packed bool container; iterator walk about 12× a byte vector; index about 4.2× and push about 6.9×; smaller in bytes; not corpus-triaged |
| CX001 | **removed** | tombstone | see `evidence/_removed/` |
| CX003 | **removed** | tombstone | see `evidence/_removed/` |
| CX004 | **removed** | tombstone | see `evidence/_removed/` |

Active slug count: **6** (`cx-regex-ctor-in-loop`, `cx-endl-in-loop`, `cx-clock-in-loop`, `cx-ifstream-in-loop`, `cx-const-by-value`, `cx-vector-bool`). `cx-string-append-unreserved` was removed after the recorded `-O2` run stayed about 1.09×. Measured JSONL stays **hint**. `cx-sstream-in-loop` was removed after a fair `-O2` run stayed about 1.2×. Jitter removals: CX001/CX003/CX004. Measured JSONL alone does not escalate a rule beyond **hint**. An unknown slug stays **hint**.
