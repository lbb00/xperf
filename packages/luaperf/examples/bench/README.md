# luaperf evidence benches

- `evidence_lu001.lua` — regenerates `../../evidence/lu-table-insert-hot.jsonl` (same timer protocol).
  - Env: `LU001_N`, `LU001_N_SMALL`, `LU001_SMALL_REPS`, `LU001_ROUNDS`, `LU001_WARM`, `EVIDENCE_DIR`.
- `evidence_lu002.lua` — regenerates `../../evidence/lu-string-concat-hot.jsonl` (Lua 5.4 `os.clock()`, warm=3, median of 9).
  - Env: `LU002_N_DIGITS`, `LU002_N_CHUNK`, `LU002_N_SMALL`, `LU002_ROUNDS`, `LU002_WARM`, `EVIDENCE_DIR`.
- `evidence_lu003.lua` — regenerates `../../evidence/lu-print-hot.jsonl` (same timer protocol; `_G.print` → `/dev/null`).
  - Env: `LU003_N`, `LU003_N_SMALL`, `LU003_ROUNDS`, `LU003_WARM`, `EVIDENCE_DIR`.
