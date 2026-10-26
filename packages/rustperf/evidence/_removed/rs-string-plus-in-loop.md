# rs-string-plus-in-loop — String += / push_str in loop

## Claim

Plain `s += "…"` / `push_str` on a single growing `String` is **amortized ~1×** vs `String::with_capacity` under rustc `-C opt-level=3` (geometric growth already avoids Lua/`..`-style copies). Tiny builders can show a small capacity win when many fresh `String::new()` starts are repeated. This rule does **not** cover `format!` rebind accumulation — that is **rs-format-rebind-in-loop**.

## How measured

- Harness: `packages/rustperf/examples/bench/evidence_rs002.rs` (pairs A/B/D)
- Build: `rustc -C opt-level=3 evidence_rs002.rs -o out/evidence_rs002`
- Timer: `std::time::Instant` wall clock; warm=3; median of 9; `std::hint::black_box`
- Pair A (matches fixture `rustperf-lint/fixtures/bad/rs-string-plus-in-loop_string_plus.rs` / capacity intent): N=500000
  - **before:** `s += "x"` from `String::new()`
  - **after:** `String::with_capacity(N)` + `push_str("x")`
- Pair B (fixed 32-byte chunks): N=100000
  - **before:** `push_str(chunk)` without capacity
  - **after:** `with_capacity(N*32)` + `push_str`
- Pair D (small N=100, ×20000 outer reps for timer floor): expect modest / ~1–2×
- Raw lines: [`rs-string-plus-in-loop.jsonl`](rs-string-plus-in-loop.jsonl) (format! pair moved to [`rs-format-rebind-in-loop.jsonl`](../rs-format-rebind-in-loop.jsonl))

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-22 Asia/Shanghai (machine clock; JSONL `ts` is UTC) |
| rustc | **1.85.1** |
| Opt | **opt-level=3** (`-C opt-level=3`) |
| Median before (`plus_eq_loop`) | 0.345 ms |
| Median after (`plus_with_capacity`) | 0.344 ms |
| **ratio plus before/after** | **~1.00×** |
| Median before (`chunk32_push_str_loop`) | 0.283 ms |
| Median after (`chunk32_with_capacity`) | 0.270 ms |
| **ratio chunk32 before/after** | **~1.05×** |
| Median before (`small_n_plus_eq`) | 3.238 ms |
| Median after (`small_n_with_capacity`) | 1.588 ms |
| **ratio small N** | **~2.04×** |

Direction: fixture-shaped `+=` / `push_str` stays ~1×. Absolute ms and ratios are N/machine/opt-sensitive. Re-run the harness after rustc or machine changes.

## Lint mapping

`rustperf-lint` **rs-string-plus-in-loop** flags `+=` / `.push_str(` inside a real `for`/`while`/`loop` window (reverse-opt skips tiny seps, help/error formatters, `clap_complete` shells — see G3 triage). Default severity **`hint`**: JSONL exists but the flagged smell is amortized ~1×. Do not CI-error clap-like builders. Hot `format!("{s}…")` / `s = format!(…)` rebind is **rs-format-rebind-in-loop** (separate detector + evidence).

## Limits

- Microbench; not an app profile.
- Rust `String` growth is geometric — do **not** equate rs-string-plus-in-loop with Lua `..` / lu-string-concat-in-loop quadratic copies for plain `push_str`.
- Pair D multiplies small builders for timer resolution; `ops` is chars per builder (100), not total appends.
- Does not measure `Write` trait objects, `itoa`, or SSO.
- Historical note: early G3 was OK-idiom-heavy; kit later flipped **corpus-ready** (see docs/corpus.md). rs-println-in-loop has since been measured (hint).
