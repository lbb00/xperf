# rustperf evidence benches

Each harness writes JSONL under `EVIDENCE_DIR` (default: the package `evidence/` directory). Build with `rustc -C opt-level=3`, run from this directory.

- `evidence_rs001.rs` — regenerates `../../evidence/rs-alloc-hot.jsonl`
  - Env: `RS001_*` size knobs, `RS001_OPT`, `RS001_RUSTC`
- `evidence_rs002.rs` — regenerates `../../evidence/rs-string-plus-in-loop.jsonl`
  - Build: `rustc -C opt-level=3 evidence_rs002.rs -o out/evidence_rs002`
  - Run: `EVIDENCE_DIR=../../evidence ./out/evidence_rs002`
  - Env: `RS002_N_PLUS`, `RS002_N_CHUNK`, `RS002_N_FMT`, `RS002_N_SMALL`,
    `RS002_SMALL_REPS`, `RS002_OPT`, `RS002_RUSTC`, `EVIDENCE_TS`, `EVIDENCE_DIR`
  - The `format!` pair is also recorded as `../../evidence/rs-format-rebind-hot.jsonl` (aliased, same timings)
- `evidence_rs003_rs005_rs006.rs` — regenerates the JSONL for `rs-println-hot`, `rs-vec-no-capacity`, and `rs-collect-vec-hot`
  - Env: `RS003_N`, `RS005_*`, `RS006_*` size knobs

Protocol: warm=3, median of 9, `Instant` wall clock, `black_box`.
