# rs-alloc-in-loop — alloc/clone in loop (Vec::new / .clone / to_string / to_owned)

## Claim

Fresh `Vec::new()` **inside** a hot loop (build buffer, drop, repeat) is only **~2.7×** slower than `clear`/`with_capacity` reuse under rustc `-C opt-level=3` on this machine. Fixture-shaped fixed `seed.clone()` into a `Vec` is **~1.1×** with/without `Vec::with_capacity` (clone cost dominates). Growing `String::clone` each step vs `clear`+`push_str` reuse is **~2.2×**. `i.to_string()` vs reused `clear`+`write!` is **~1.7×**. Small-N repeated short-lived `Vec::new` can show **~9×**, but that is still far below the lu-string-concat-in-loop / rs-format-rebind-in-loop class of wins and the detector also hits G3 OK-idiom Id/`to_owned` builders. **Do not** escalate whole rs-alloc-in-loop to `error`; **do not** invent a sub-rule escalate without a detector that excludes OK-idiom.

## How measured

- Harness: `packages/rustperf/examples/bench/evidence_rs001.rs`
- Build: `rustc -C opt-level=3 evidence_rs001.rs -o out/evidence_rs001`
- Timer: `std::time::Instant` wall clock; warm=3; median of 9; `std::hint::black_box`
- Pair A: outer=50000 × inner=64 pushes
  - **before:** `Vec::new()` each outer iter
  - **after:** one `Vec::with_capacity(inner)` + `clear` each outer
- Pair B (matches fixture `rustperf-lint/fixtures/bad/rs-alloc-in-loop_clone_loop.rs` capacity intent): N=200000, seed_len=64
  - **before:** `Vec::new` + `seed.clone()` push
  - **after:** `Vec::with_capacity(N)` + same clones
- Pair C (growing-ish clone): N=8000
  - **before:** grow `acc` by one char; `acc.clone()` each step
  - **after:** same grow; `buf.clear(); buf.push_str(&acc)` reuse
- Pair D: N=200000 digits
  - **before:** `i.to_string()`
  - **after:** reused `String` + `clear` + `write!(s, "{i}")`
- Pair E (small N limit): outer=100 × inner=16, ×20000 outer reps for timer floor
- Raw lines: [`rs-alloc-in-loop.jsonl`](rs-alloc-in-loop.jsonl)

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-22 Asia/Shanghai (machine clock; JSONL `ts` is UTC) |
| rustc | **1.99.1** |
| Opt | **opt-level=3** (`-C opt-level=3`) |
| Median before (`vec_new_each_iter`) | 4.955 ms |
| Median after (`vec_clear_reuse`) | 1.810 ms |
| **ratio Vec::new each** | **~6.11×** |
| Median before (`clone_vec_new`) | 5.979 ms |
| Median after (`clone_with_capacity`) | 5.398 ms |
| **ratio fixture clone** | **~1.08×** |
| Median before (`grow_clone_each`) | 0.550 ms |
| Median after (`grow_clear_push_str`) | 0.247 ms |
| **ratio growing clone** | **~1.81×** |
| Median before (`to_string_each_iter`) | 4.342 ms |
| Median after (`to_string_clear_write`) | 2.488 ms |
| **ratio to_string** | **~1.56×** |
| Median before (`small_n_vec_new_each`) | 178.412 ms |
| Median after (`small_n_vec_clear_reuse`) | 19.802 ms |
| **ratio small N** | **~11.95×** |

Direction: reuse/`clear` wins modestly on fresh `Vec::new`; fixture `clone` is ~1×; nothing here matches rs-format-rebind-in-loop ~99×. Absolute ms and ratios are N/machine/opt-sensitive. Re-run the harness after rustc or machine changes.

## Lint mapping

`rustperf-lint` **rs-alloc-in-loop** flags `Vec::new` / `.to_string()` / `.to_owned()` / (reverse-opt) buffer-ish `.clone()` inside a real `for`/`while`/`loop` window. Default severity is **`off`** (use `--severity rs-alloc-in-loop=hint` to review): JSONL exists, but ratios are modest (~1–9×) and G3 clap/serde residuals are mostly OK-idiom Id/`to_owned` builders. Do **not** mass-escalate. A future narrow split (e.g. only `Vec::new` *inside* the loop body, excluding one-shot builders) would still need its own detector + evidence before `error`.

## Limits

- Microbench; not an app profile.
- Pair B capacity-only after does not remove clone allocations — expect ~1×.
- Pair C reuse still copies bytes; win is mostly avoiding a fresh `String` alloc per step.
- Pair E multiplies small builders for timer resolution; `ops` is outer builds per rep unit (100), not total pushes.
- Historical note: early G3 was OK-idiom-heavy; kit later flipped **corpus-ready** via rs-vec-no-capacity/rs-collect-vec-in-loop (see docs/corpus.md). rs-println-in-loop has since been measured (hint).
