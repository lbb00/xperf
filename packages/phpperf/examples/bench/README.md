# phpperf evidence benches

- `evidence_ph001_ph003.php` — regenerates `../../evidence/ph-string-dot-hot.jsonl` and `../../evidence/ph-echo-hot.jsonl` (same timer protocol).
  - Env: `PH001_N`, `PH001_N_SMALL`, `PH003_N`, `PH_ROUNDS`, `PH_WARM`, `EVIDENCE_DIR`.
- `evidence_ph002.php` — regenerates `../../evidence/ph-array-merge-rebind.jsonl` (PHP `hrtime(true)` wall, warm=3, median of 9).
  - Env: `PH002_N_SCALAR`, `PH002_N_CHUNK`, `PH002_CHUNK_LEN`, `PH002_N_SMALL`, `PH002_ROUNDS`, `PH002_WARM`, `EVIDENCE_DIR`.
