# luaperf changelog

## 2026-10-22

- **lu-string-concat-in-loop** default severity **hint → error** after G4 microbench on Lua 5.4.7
  (`evidence/lu-string-concat-in-loop.md` + `lu-string-concat-in-loop.jsonl`; harness `examples/bench/evidence_lu002.lua`).
- Skip directory segment `bench` in corpus walks (alongside `benchmark`), so evidence
  harnesses under `examples/bench/` do not self-fire.
- Docs: evidence-policy map, rule-regression, guide severity table, corpus note.
- **lu-print-in-loop** G4 microbench on Lua 5.4.7 (`evidence/lu-print-in-loop.md` + `lu-print-in-loop.jsonl`; harness
  `examples/bench/evidence_lu003.lua`). print/quiet ~85× to `/dev/null`; severity stays
  **hint** (I/O sink–dependent, JP002-style).

## 2026-10-22

- G3 reverse-opt: **lu-table-insert-in-loop** default **off** (OK-idiom on Kong/APISIX); lu-string-concat-in-loop narrowed to accumulation.

## Scaffold

- Initial lu-table-insert-in-loop–lu-print-in-loop heuristic checker.
