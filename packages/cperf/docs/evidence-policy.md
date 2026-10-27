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
| cp-alloc-hot | **error** | [cp-alloc-hot.md](../evidence/cp-alloc-hot.md) · [cp-alloc-hot.jsonl](../evidence/cp-alloc-hot.jsonl) | Agree ~**10.8×** malloc-in-loop vs arena |
| cp-realloc-grow-one | **error** | [cp-realloc-grow-one.md](../evidence/cp-realloc-grow-one.md) · [cp-realloc-grow-one.jsonl](../evidence/cp-realloc-grow-one.jsonl) | Agree ~**12.6×** (companion case4 ~3×); direction clear |
| cp-printf-hot | **off** (default) | [cp-printf-hot.md](../evidence/cp-printf-hot.md) · [cp-printf-hot.jsonl](../evidence/cp-printf-hot.jsonl) | Hot unbuf/buf ~**4.8×** YES; G3 corpora almost-all OK-idiom/`#if 0` → **off**; use `--preset all` or `--severity cp-printf-hot=hint` |
| cp-strlen-in-cond | **hint** | [cp-strlen-in-cond.md](../evidence/cp-strlen-in-cond.md) | about 125× when the string might change; about 0.93× when `-O2` hoists; stay hint |
| cp-strcat-hot | **off** (default) | [cp-strcat-hot.md](../evidence/cp-strcat-hot.md) | about 221× versus an end pointer; stays off (G3) |
| cp-sprintf-hot | **hint** | [cp-sprintf-hot.md](../evidence/cp-sprintf-hot.md) · [cp-sprintf-hot.jsonl](../evidence/cp-sprintf-hot.jsonl) | pending; not corpus-triaged |
| cp-fopen-hot | **hint** | [cp-fopen-hot.md](../evidence/cp-fopen-hot.md) · [cp-fopen-hot.jsonl](../evidence/cp-fopen-hot.jsonl) | pending; not corpus-triaged |
| cp-gettime-hot | **hint** | [cp-gettime-hot.md](../evidence/cp-gettime-hot.md) · [cp-gettime-hot.jsonl](../evidence/cp-gettime-hot.jsonl) | pending; not corpus-triaged; bare `time` is not matched |
| cp-wide-bool-flags | **hint** | [cp-wide-bool-flags.md](../evidence/cp-wide-bool-flags.md) · [cp-wide-bool-flags.jsonl](../evidence/cp-wide-bool-flags.jsonl) | JSONL present; stays hint; not corpus-triaged; four full-width flags, no bit-field |
| cp-regex-hot | **hint** | [cp-regex-hot.md](../evidence/cp-regex-hot.md) · [cp-regex-hot.jsonl](../evidence/cp-regex-hot.jsonl) | about 9.7×; stay hint; not corpus-triaged; `regexec` is not matched |
| cp-alloca-hot | **hint** | [cp-alloca-hot.md](../evidence/cp-alloca-hot.md) · [cp-alloca-hot.jsonl](../evidence/cp-alloca-hot.jsonl) | stack cover 1280000 vs 64 bytes; wall clock about 1×; stay hint; not corpus-triaged; a VLA is not matched |
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

Default `--preset app` (and `engine`): **cp-alloc-hot=error**, **cp-realloc-grow-one=error**, **cp-strlen-in-cond=hint**, **cp-sprintf-hot=hint**, **cp-fopen-hot=hint**, **cp-gettime-hot=hint**, **cp-wide-bool-flags=hint**, **cp-regex-hot=hint**, **cp-alloca-hot=hint**, **cp-struct-by-value=hint**, **cp-printf-hot=off** and **cp-strcat-hot=off**. The off rules are the G3 2026-10-22 demotions. Hints are not corpus-triaged. `cp-regex-hot`, `cp-alloca-hot`, and `cp-struct-by-value` have JSONL and stay hint. An unknown slug stays **hint**.

`--preset all` elevates every rule to error for dogfood. Overrides: `--severity RULE=error|hint|off`.
