# cperf evidence policy

## Gate

A cperf rule may be documented / treated as **`error`** only if both exist under `packages/cperf/evidence/`:

1. `<slug>.md` — claim, how measured, `cc` version / flags, limits
2. `<slug>.jsonl` — ≥1 before/after line with fields `rule`, `case`, `median_ms`, `ops`, `ratio`, `ts`, plus `cc` (compiler and flags; `node` and `v8` stay null). Optional `role`: `before` = smell, `after` = fix.

Otherwise the rule is at most **`hint`**.

Having JSONL is necessary but not sufficient: if measured agreement is only partial (static fire without wall-clock cost on common shapes), keep **`hint`** and document the negative in the md.

## Current map

As of 2026-10-22.

| Rule | Severity | Evidence | Verdict |
|------|----------|----------|---------|
| cp-alloc-in-loop | **error** | [cp-alloc-in-loop.md](../evidence/cp-alloc-in-loop.md) · [cp-alloc-in-loop.jsonl](../evidence/cp-alloc-in-loop.jsonl) | Agree ~**10.8×** malloc-in-loop vs arena |
| cp-realloc-grow-one | **error** | [cp-realloc-grow-one.md](../evidence/cp-realloc-grow-one.md) · [cp-realloc-grow-one.jsonl](../evidence/cp-realloc-grow-one.jsonl) | Agree ~**12.6×** (companion case4 ~3×); direction clear |
| cp-printf-in-loop | **off** (default) | [cp-printf-in-loop.md](../evidence/cp-printf-in-loop.md) · [cp-printf-in-loop.jsonl](../evidence/cp-printf-in-loop.jsonl) | Hot unbuf/buf ~**4.8×** YES; G3 corpora almost-all OK-idiom/`#if 0` → **off**; use `--preset all` or `--severity cp-printf-in-loop=hint` |
| cp-strlen-in-cond | **hint** | [cp-strlen-in-cond.md](../evidence/cp-strlen-in-cond.md) | about 125× when the string might change; about 0.93× when `-O2` hoists; stay hint |
| cp-strcat-in-loop | **off** (default) | [cp-strcat-in-loop.md](../evidence/cp-strcat-in-loop.md) | about 221× versus an end pointer; stays off (G3) |
| cp-sprintf-in-loop | **hint** | [cp-sprintf-in-loop.md](../evidence/cp-sprintf-in-loop.md) · [cp-sprintf-in-loop.jsonl](../evidence/cp-sprintf-in-loop.jsonl) | pending; not corpus-triaged |
| cp-fopen-in-loop | **hint** | [cp-fopen-in-loop.md](../evidence/cp-fopen-in-loop.md) · [cp-fopen-in-loop.jsonl](../evidence/cp-fopen-in-loop.jsonl) | pending; not corpus-triaged |
| cp-gettime-in-loop | **hint** | [cp-gettime-in-loop.md](../evidence/cp-gettime-in-loop.md) · [cp-gettime-in-loop.jsonl](../evidence/cp-gettime-in-loop.jsonl) | pending; not corpus-triaged; bare `time` is not matched |
| cp-wide-bool-flags | **hint** | [cp-wide-bool-flags.md](../evidence/cp-wide-bool-flags.md) · [cp-wide-bool-flags.jsonl](../evidence/cp-wide-bool-flags.jsonl) | JSONL present; stays hint; not corpus-triaged; four full-width flags, no bit-field |
| cp-regex-in-loop | **hint** | [cp-regex-in-loop.md](../evidence/cp-regex-in-loop.md) · [cp-regex-in-loop.jsonl](../evidence/cp-regex-in-loop.jsonl) | about 9.7×; stay hint; not corpus-triaged; `regexec` is not matched |
| cp-alloca-in-loop | **hint** | [cp-alloca-in-loop.md](../evidence/cp-alloca-in-loop.md) · [cp-alloca-in-loop.jsonl](../evidence/cp-alloca-in-loop.jsonl) | stack cover 1280000 vs 64 bytes; wall clock about 1×; stay hint; not corpus-triaged; a VLA is not matched |
| cp-struct-by-value | **hint** | [cp-struct-by-value.md](../evidence/cp-struct-by-value.md) · [cp-struct-by-value.jsonl](../evidence/cp-struct-by-value.jsonl) | about 12.3× cross-TU at 512 bytes; same TU about 1×; stay hint; not corpus-triaged |

## Regenerating

```sh
bash packages/cperf/scripts/regen-evidence-cp001.sh
bash packages/cperf/scripts/regen-evidence-cp002.sh
bash packages/cperf/scripts/regen-evidence-cp003.sh
# optional correlation suite → examples/bench/build/static-vs-o2/
bash packages/cperf/scripts/run-static-vs-o2.sh
```

Update the matching `<slug>.md` medians if the ratio moves materially.

## CLI presets

Default `--preset app` (and `engine`): **cp-alloc-in-loop=error**, **cp-realloc-grow-one=error**, **cp-strlen-in-cond=hint**, **cp-sprintf-in-loop=hint**, **cp-fopen-in-loop=hint**, **cp-gettime-in-loop=hint**, **cp-wide-bool-flags=hint**, **cp-regex-in-loop=hint**, **cp-alloca-in-loop=hint**, **cp-struct-by-value=hint**, **cp-printf-in-loop=off** and **cp-strcat-in-loop=off**. The off rules are the G3 2026-10-22 demotions. Hints are not corpus-triaged. `cp-regex-in-loop`, `cp-alloca-in-loop`, and `cp-struct-by-value` have JSONL and stay hint. An unknown slug stays **hint**.

`--preset all` elevates every rule to error for dogfood. Overrides: `--severity RULE=error|hint|off`.
