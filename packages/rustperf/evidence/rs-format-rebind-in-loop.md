# rs-format-rebind-in-loop — format! rebind accumulation in loop

## Claim

Hot-loop `s = format!("{s}…")` / `s = format!("{}{}", s, …)` accumulation on Rust is substantially slower than `String::with_capacity` + `write!` / `push_str`, because each `format!` allocates a fresh `String` and copies the growing prefix (quadratic-ish).

## How measured

Same harness and run as the former rs-string-plus-in-loop format! pair (not re-invented):

- Harness: `packages/rustperf/examples/bench/evidence_rs002.rs` (Pair C)
- Build: `rustc -C opt-level=3 evidence_rs002.rs -o out/evidence_rs002`
- Timer: `std::time::Instant` wall clock; warm=3; median of 9; `std::hint::black_box`
- Pair C (matches fixtures `rustperf-lint/fixtures/bad/rs-format-rebind-in-loop_format_rebind.rs` / good `rs-format-rebind-in-loop_write.rs`): N=20000
  - **before:** `s = format!("{s}{i}")` in loop
  - **after:** `with_capacity` + `write!(s, "{i}")`
- Raw lines: [`rs-format-rebind-in-loop.jsonl`](rs-format-rebind-in-loop.jsonl) — **aliased** from the 2026-10-22 rs-string-plus-in-loop G4 JSONL (`rule` field set to `rs-format-rebind-in-loop`; `aliased_from=rs-string-plus-in-loop`; same `median_ms` / `ops` / `ts`)

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-22 Asia/Shanghai (machine clock; JSONL `ts` is UTC) |
| rustc | **1.99.1** |
| Opt | **opt-level=3** (`-C opt-level=3`) |
| Median before (`digits_format_accum`) | 28.652 ms |
| Median after (`digits_write`) | 0.288 ms |
| **ratio format! before/after** | **~100×** |

Direction: `format!` rebind accumulation is a large, stable win for the **flagged** smell. Absolute ms and ratios are N/machine/opt-sensitive.

## Lint mapping

`rustperf-lint` **rs-format-rebind-in-loop** fires only when a loop line has `ident = format!(…)` (**not** `let ident = format!(…)`) and the format body/args reuse `ident` (`{ident}` or positional token). Bare `format!(…)` exprs and fresh let-bindings stay quiet. Default severity **`error`** under [evidence-policy](../docs/evidence-policy.md): the flagged smell itself is ~99×. Path skips mirror rs-string-plus-in-loop (shells / cold CLI formatters). Amortized `+=` / `push_str` stays on **rs-string-plus-in-loop** (hint).

## Limits

- Microbench; not an app profile.
- Line heuristic can still hit one-shot wraps that reuse the LHS once per outer iteration (see G3 residual note) — override with `--severity rs-format-rebind-in-loop=off` / `hint` if needed.
- Does not measure `Write` trait objects, `itoa`, or SSO.
- Historical note: written before r4 redesign; kit is now **corpus-ready** (see docs/corpus.md).
