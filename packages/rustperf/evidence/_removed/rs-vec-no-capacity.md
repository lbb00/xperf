# rs-vec-no-capacity — Vec::new + push vs with_capacity

## Claim

On a **large** known-size fill (N=500000, rustc `-C opt-level=3`), `Vec::new()` + `push` is already amortized by geometric growth and measures **~1.0×** vs `with_capacity` (noise). On **repeated small** builders (N=100 × 10000 reps) `with_capacity` wins **~2.07×**. Useful as a hint for tight inner builders; **not** an escalate-to-error case.

## How measured

- Harness: `packages/rustperf/examples/bench/evidence_rs003_rs005_rs006.rs`
- Build: `rustc -C opt-level=3`
- Pair A: N=500000 items copy
- Pair B: N=100 × 10000 outer reps
- Raw: [`rs-vec-no-capacity.jsonl`](rs-vec-no-capacity.jsonl)

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-22 Asia/Shanghai |
| rustc | **1.85.1** / opt-level=3 |
| Median before (`vec_new_push`) | 0.544 ms |
| Median after (`with_capacity`) | 0.545 ms |
| **ratio hot large** | **~1.00×** |
| Median before (`small_vec_new_push`) | 2.044 ms |
| Median after (`small_with_capacity`) | 0.989 ms |
| **ratio small builders** | **~2.07×** |

## Lint mapping

Default stays **`hint`**. Escalate recommended: **no**.

## Limits

- Microbench; capacity-only win is modest once growth amortizes.

## Landed 2026-10-22

Scope note: wins show for **many small builders** or very large realloc spikes; a single large fill is already amortized by geometric growth. Keep **hint**; do not escalate.

## Memory (2026-10-22)

Counting allocator live bytes N=500k `u32`: `Vec::new` **2097152** vs `with_capacity` **2000000** (**1.049×**). [`rs-vec-no-capacity.mem.jsonl`](rs-vec-no-capacity.mem.jsonl).
