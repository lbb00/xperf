# cp-realloc-grow-one — realloc grow-by-one

## Claim

Growing a buffer with `realloc(p, (len+1) * sizeof T)` on every push is substantially slower than capacity doubling under `cc -O2` on this Linux machine when the growth is on the measured path.

## How measured

- Source: `packages/cperf/examples/bench/cp002_realloc_growth.c`
- Build: `cc -std=c11 -O2 -o cp002_realloc_growth cp002_realloc_growth.c`
- Timing: `clock_gettime(CLOCK_MONOTONIC)`; warm=3; median of 9 rounds; N=100000
- **before:** `realloc` to `len+1` each push
- **after:** double capacity when `len+1 > cap`
- Raw lines: [`cp-realloc-grow-one.jsonl`](cp-realloc-grow-one.jsonl)
- Companion: `examples/bench/case4_realloc_growth.c` via `scripts/run-static-vs-o2.sh`

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-21 Asia/Shanghai (JSONL `ts` is UTC) |
| Compiler | **cc (Debian 14.2.0-19) 14.2.0** · flags `cc -std=c11 -O2` |
| Median before (`realloc_plus_one`) | ~0.63 ms |
| Median after (`capacity_doubling`) | ~0.05 ms |
| **ratio before/after** | **~12.6×** |

Companion STATIC-VS-O2 case4 (same day, median of 7): smell ~0.81 ms → clean ~0.25 ms ≈ **3.2×**. Absolute ratios differ by harness (timing window / warm), but **direction and agreement with the smell are clear**.

## Lint mapping

`cperf-lint` cp-realloc-grow-one fires on best-effort `realloc(..., …+1)` / `old+1` style second args. Severity **error** under [evidence-policy](../docs/evidence-policy.md) — JSONL exists and wall-clock agrees when the pattern is hot.

## Limits

- Rare on mature trees (corpus dogfood almost never hits).
- Legitimate one-shot `realloc(p, n+1)` for a known final size is not the smell; lint is a heuristic on the second argument shape.
- Does not model custom allocators or amortized growth with a different factor.
