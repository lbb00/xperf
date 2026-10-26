# rustperf evidence policy

## Gate

A rule may be treated as **`error`** only if both exist under `packages/rustperf/evidence/`:

1. `<RULE>.md` — claim, how measured, toolchain version, limits
2. `<RULE>.jsonl` — ≥1 before/after line with `rule`, `case`, `median_ms`, `ops`, `ratio`, `ts`

Otherwise the rule stays **`hint`**.

JSONL alone is not enough: escalate only when the **flagged smell** itself shows a large, stable speed win (as rs-format-rebind-in-loop does). Mixed detectors that also hit ~1× amortized patterns stay **hint**.

## Current map

As of 2026-10-22.

| Rule | Severity (default) | Evidence | Smell |
|------|--------------------|----------|-------|
| rs-alloc-in-loop | off | **yes** (`rs-alloc-in-loop.md` + `rs-alloc-in-loop.jsonl`) | alloc/clone in loop — Vec::new ~2.7× / fixture clone ~1.1× / to_string ~1.7×; stays **off** (G3 OK-idiom; no narrow split to escalate); `--severity rs-alloc-in-loop=hint` to review |
| rs-println-in-loop | hint | **yes** (`rs-println-in-loop.md` + `rs-println-in-loop.jsonl`) | println! / eprintln! in loop (~12.6× buffered vs per-line; I/O, environment-dependent) |
| rs-format-rebind-in-loop | **error** | **yes** (`rs-format-rebind-in-loop.md` + `rs-format-rebind-in-loop.jsonl`, aliased from rs-string-plus-in-loop G4 format! pair) | `format!` rebind accum in loop (~99× vs `write!`); brace-wrap skipped |
| rs-collect-vec-in-loop | hint | **yes** (`rs-collect-vec-in-loop.md` + `.jsonl`) | collect::<Vec> in loop (~1.8×) |
| rs-map-new-in-loop | hint | measured (`rs-map-new-in-loop.md` + `rs-map-new-in-loop.jsonl`); stay hint | `HashMap::new` in a loop; two quiet runs about 1.5×; not corpus-triaged |
| rs-regex-new-in-loop | hint | measured (`rs-regex-new-in-loop.md` + `rs-regex-new-in-loop.jsonl`); stay hint | `Regex::new` in loop; not corpus-triaged |
| rs-file-open-in-loop | hint | measured (`rs-file-open-in-loop.md` + `rs-file-open-in-loop.jsonl`); stay hint | `File::open` in a loop; same path only; not corpus-triaged |
| rs-clock-in-loop | hint | measured (`rs-clock-in-loop.md` + `rs-clock-in-loop.jsonl`); stay hint | `Instant::now` in a loop; not corpus-triaged |

rs-alloc-in-loop G4 2026-10-22: measured modest wins only; **do not** mass-escalate (OK-idiom dominate G3). `rs-string-plus-in-loop` was removed after the large fill stayed about 1×. Hot `s = format!("{s}…")` stays on rs-format-rebind-in-loop (**error**). `rs-vec-no-capacity` was removed after a large fill stayed about 1×.
