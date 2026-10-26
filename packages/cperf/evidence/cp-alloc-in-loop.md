# cp-alloc-in-loop — allocation in loop body

## Claim

Calling `malloc`/`free` once per iteration of a tight loop is substantially slower than bumping from a pre-sized arena for the same N small objects under `cc -O2` on this Linux machine.

## How measured

- Source: `packages/cperf/examples/bench/cp001_malloc_vs_arena.c`
- Build: `cc -std=c11 -O2 -o cp001_malloc_vs_arena cp001_malloc_vs_arena.c`
- Timing: `clock_gettime(CLOCK_MONOTONIC)`; warm=3; median of 9 rounds; N=200000
- **before:** `malloc(sizeof(int))` + write + `free` each iteration
- **after:** one arena sized for N ints; bump-allocate each iteration; free arena once
- Raw lines: [`cp-alloc-in-loop.jsonl`](cp-alloc-in-loop.jsonl)
- Companion: `scripts/run-static-vs-o2.sh` case1 (same pattern; ratio varies with harness wiring)

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-21 Asia/Shanghai (JSONL `ts` is UTC) |
| Compiler | **cc (Debian 14.2.0-19) 14.2.0** · flags `cc -std=c11 -O2` |
| Median before (`malloc_free_in_loop`) | ~1.34 ms |
| Median after (`arena_bump`) | ~0.12 ms |
| **ratio before/after** | **~10.8×** |

Re-measure 2026-10-21 19:19 Asia/Shanghai: previous gate was ~10.0× (1.44 → 0.14 ms). Drift not material; claim unchanged.

## Lint mapping

`cperf-lint` cp-alloc-in-loop fires on `malloc`/`calloc`/`realloc` inside a `for`/`while`/`do` body (brace-depth heuristic; thin `return realloc(...)` wrappers skipped). Severity **error** under [evidence-policy](../docs/evidence-policy.md) because this JSONL exists and agrees.

## Limits

- Microbench of tiny fixed-size allocs; real hot paths may need pools, stack buffers, or hoisted reuse — arena is one valid fix, not the only one.
- Init loops that allocate once per known N with long lifetimes are often fine; treat lint as a review prompt when the loop is not hot.
- Does not measure fragmentation or multi-threaded allocators.
