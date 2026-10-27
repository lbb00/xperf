# luaperf changelog

## 2026-10-22

- **lu-string-concat-hot** default severity **hint → error** after G4 microbench on Lua 5.4.7
  (`evidence/lu-string-concat-hot.md` + `lu-string-concat-hot.jsonl`; harness `examples/bench/evidence_lu002.lua`).
- Skip directory segment `bench` in corpus walks (alongside `benchmark`), so evidence
  harnesses under `examples/bench/` do not self-fire.
- Docs: evidence-policy map, rule-regression, guide severity table, corpus note.
- **lu-print-hot** G4 microbench on Lua 5.4.7 (`evidence/lu-print-hot.md` + `lu-print-hot.jsonl`; harness
  `examples/bench/evidence_lu003.lua`). print/quiet ~85× to `/dev/null`; severity stays
  **hint** (I/O sink–dependent, JP002-style).

## 2026-10-22

- G3 reverse-opt: **lu-table-insert-hot** default **off** (OK-idiom on Kong/APISIX); lu-string-concat-hot narrowed to accumulation.

## Scaffold

- Initial lu-table-insert-hot–lu-print-hot heuristic checker.
