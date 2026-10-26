# rubyperf evidence policy

## Gate

A rule may be treated as **`error`** only if both exist under `packages/rubyperf/evidence/`:

1. `<RULE>.md` — claim, how measured, toolchain version, limits
2. `<RULE>.jsonl` — ≥1 before/after line with `rule`, `case`, `median_ms`, `ops`, `ratio`, `ts`

Otherwise the rule stays **`hint`** (or **`off`**).

Measured JSONL alone does not escalate a rule: the flagged smell must also hold up on the G3 corpus triage (see [corpus.md](corpus.md)).

## Current map

As of 2026-10-22.

| Rule | Severity (default) | Evidence | Smell |
|------|--------------------|----------|-------|
| rb-string-plus-in-loop | off | **yes** (`rb-string-plus-in-loop.md` + `.jsonl`, ~32×) | string `+=` in loop (prefer `<<`) |
| rb-array-plus-rebind | off | **yes** (`rb-array-plus-rebind.md` + `.jsonl`, ~181×) | Array `+` / concat rebinding in loop |
| rb-puts-in-loop | off | **yes** (`rb-puts-in-loop.md` + `.jsonl`, ~5×; I/O is environment-dependent) | `puts` / `print` in loop |
| rb-regexp-new-in-loop | hint | measured (`rb-regexp-new-in-loop.md` + `rb-regexp-new-in-loop.jsonl`); stay hint | `Regexp.new` in loop; not corpus-triaged |
| rb-json-in-loop | hint | measured (`rb-json-in-loop.md` + `rb-json-in-loop.jsonl`); stay hint | `JSON.parse` / `generate` in loop; not corpus-triaged |
| rb-file-read-in-loop | hint | measured (`rb-file-read-in-loop.md` + `rb-file-read-in-loop.jsonl`); stay hint | `File.read` / `File.open` in a loop; same path only; not corpus-triaged |

No rule is `error`: the ratios are real but the three `off` rules were demoted after G3 OK-idiom triage. `rb-hash-merge-in-loop` was removed: on Ruby 4.0.8 the literal build was slower than `merge` and allocated more.
