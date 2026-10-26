# luaperf-lint

Heuristic Lua checker for **lu-table-insert-in-loop–lu-print-in-loop**. Line/brace (or do/end) window scanner — not a full AST/SSA pass.

| Rule | Message |
|------|---------|
| lu-table-insert-in-loop | table.insert without size / growing table in loop |
| lu-string-concat-in-loop | string .. concatenation in loop |
| lu-print-in-loop | print in loop |

Default severity: **lu-table-insert-in-loop=off**, **lu-string-concat-in-loop=error** (G4 evidence), **lu-print-in-loop=hint** (G4 evidence; I/O sink–dependent — not escalated). Re-enable lu-table-insert-in-loop with `--severity lu-table-insert-in-loop=hint`; demote lu-string-concat-in-loop with `--severity lu-string-concat-in-loop=hint`. Self-dogfood: `bash ../scripts/self-lint.sh` must stay clean on checker sources (fixtures excluded via `fixtures/` skip).

## False positives

- Init / config loops that intentionally allocate once per entry
- Test / vendored / generated trees should be skipped or out of path
