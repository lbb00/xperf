# luaperf-lint

Heuristic Lua checker for **lu-table-insert-hot–lu-print-hot**. Line/brace (or do/end) window scanner — not a full AST/SSA pass.

| Rule | Message |
|------|---------|
| lu-table-insert-hot | table.insert without size / growing table in loop |
| lu-string-concat-hot | string .. concatenation in loop |
| lu-print-hot | print in loop |

Default severity: **lu-table-insert-hot=off**, **lu-string-concat-hot=error** (G4 evidence), **lu-print-hot=hint** (G4 evidence; I/O sink–dependent — not escalated). Re-enable lu-table-insert-hot with `--severity lu-table-insert-hot=hint`; demote lu-string-concat-hot with `--severity lu-string-concat-hot=hint`. Self-dogfood: `bash ../scripts/self-lint.sh` must stay clean on checker sources (fixtures excluded via `fixtures/` skip).

## False positives

- Init / config loops that intentionally allocate once per entry
- Test / vendored / generated trees should be skipped or out of path
