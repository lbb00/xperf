# luaperf evidence policy

## Gate

A rule may be treated as **`error`** only if both exist under `packages/luaperf/evidence/`:

1. `<RULE>.md` — claim, how measured, toolchain version, limits
2. `<RULE>.jsonl` — ≥1 before/after line with `rule`, `case`, `median_ms`, `ops`, `ratio`, `ts`

Otherwise the rule stays **`hint`**.

## Current map

As of 2026-10-22.

| Rule | Severity | Evidence | Smell |
|------|----------|----------|-------|
| lu-table-insert-hot | off | measured (`lu-table-insert-hot.md` + `lu-table-insert-hot.jsonl`); kept off | table.insert without size / growing table in loop |
| lu-string-concat-hot | **error** | yes (`lu-string-concat-hot.md` + `lu-string-concat-hot.jsonl`) | string .. concatenation in loop |
| lu-print-hot | hint | yes (`lu-print-hot.md` + `lu-print-hot.jsonl`) | print in loop |

lu-string-concat-hot escalated after G4 microbench on Lua 5.4.7 (fixture-shaped digits ~6.6×; fixed 32-byte chunks ~117×; small N ~1×). lu-table-insert-hot stays `off` (G3 OK-idiom). lu-print-hot has G4 evidence (print/quiet ~85× to `/dev/null` on Lua 5.4.7) but stays **hint** — I/O sink–dependent, JP002/CP003-style (debug/CLI printers common; buffer-only ~2×).
