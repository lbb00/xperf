# rustperf changelog

## 2026-10-22 (rs-vec-no-capacity/rs-collect-vec-in-loop redesign → corpus-ready)

- **rs-vec-no-capacity** (hint): `Vec`/`String::new` / `vec![]` then push in a **size-hinted** loop without `with_capacity`.
- **rs-collect-vec-in-loop** (hint): `collect::<Vec…>` inside a real loop.
- Reverse-opt: `#[cfg(test)]`/`#[test]` skip; `tests.rs`; derive-crate skip for rs-vec-no-capacity; rs-format-rebind-in-loop brace-wrap skip; rs-string-plus-in-loop `mid_string`/`sc_names` skip.
- Fixtures: `rs-vec-no-capacity_*`, `rs-collect-vec-in-loop_*`, `rs-format-rebind-in-loop_brace_wrap`, `rs-vec-no-capacity_cfg_test`.
- G3 r4 on serde/tokio/clap: **6** clap residuals, **100% TP**, FP+DOC+SKIP **0%** → **corpus-ready: yes**.
- No G4 escalate for rs-vec-no-capacity/rs-collect-vec-in-loop.


## 2026-10-22 (rs-alloc-in-loop G4 evidence, no severity bump)

- **rs-alloc-in-loop G4** microbench on rustc **1.85.1** `-C opt-level=3`
  (`evidence/rs-alloc-in-loop.md` + `rs-alloc-in-loop.jsonl`; harness `examples/bench/evidence_rs001.rs`).
  - `Vec::new` each iter vs clear/reuse: ~**2.74×** (small N ×reps ~**9×**)
  - fixture `seed.clone()` ± `with_capacity`: ~**1.11×**
  - growing `clone` vs clear+`push_str`: ~**2.23×**
  - `to_string` vs clear+`write!`: ~**1.75×**
- Default severity for rs-alloc-in-loop stayed **hint** (modest ratios; G3 OK-idiom dominate; no narrow split escalate).
- Docs: evidence-policy map, rule-regression, evidence README, kit README.

## 2026-10-22 (rs-string-plus-in-loop/rs-format-rebind-in-loop split)

- **Split rs-string-plus-in-loop:** `+=` / `push_str` only; default stays **hint** (amortized ~1×).
- **Add rs-format-rebind-in-loop:** `ident = format!(…)` rebind that reuses `ident` in the format body/args; default **error**.
  - Evidence: `evidence/rs-format-rebind-in-loop.md` + `rs-format-rebind-in-loop.jsonl` — same measured format! pair as rs-string-plus-in-loop G4
    (`digits_format_accum` ~**99×** vs `write!`; `aliased_from=rs-string-plus-in-loop`; no new timings invented).
- Fixtures: `bad/rs-format-rebind-in-loop_format_rebind.rs`, `good/rs-format-rebind-in-loop_write.rs`, `good/rs-format-rebind-in-loop_let_format.rs`.
- Docs: evidence-policy, corpus residual note, guide lint map, rule-regression, smell-catalog.

## 2026-10-22 (G4 evidence, no severity bump)

- **rs-string-plus-in-loop G4** microbench on rustc **1.85.1** `-C opt-level=3`
  (`evidence/_removed/rs-string-plus-in-loop.md` + `evidence/_removed/rs-string-plus-in-loop.jsonl`; harness `examples/bench/evidence_rs002.rs`).
  - `format!` accum vs `write!`: ~**99×**
  - fixture `+=` / `push_str` vs `with_capacity`: ~**1.00–1.05×**
  - small N (×reps for timer): ~**2×**
- Default severity for rs-string-plus-in-loop stayed **hint** (detector also hit amortized ~1× builders).
- Docs: evidence-policy map, rule-regression, guide lint note, evidence README.

## Scaffold / G3

- Initial rs-alloc-in-loop–rs-println-in-loop heuristic checker; G3 reverse-opt (real loop heads, tiny seps, cold CLI paths).
