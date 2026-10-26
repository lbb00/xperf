# cp-printf-in-loop — printf / fprintf in a loop

## Claim (narrow)

When `fprintf` runs on a **truly hot** path to a stream forced unbuffered (`_IONBF`), wall clock is several× slower than the **same call sites** with a large `_IOFBF` buffer under `cc -O2` on this Linux machine. Removing the I/O entirely is another order of magnitude.

## Claim we do *not* make

A cp-printf-in-loop lint hit alone does **not** imply the process is slow: dead helpers, `#if 0` bodies, and dump/codegen printers fire the scanner with **~1.0×** hot-path time (see STATIC-VS-O2 case3).

## How measured

- Source: `packages/cperf/examples/bench/cp003_printf_hot.c`
- Build: `cc -std=c11 -O2 -o cp003_printf_hot cp003_printf_hot.c`
- Timing: `clock_gettime(CLOCK_MONOTONIC)`; warm=2; median of 9 rounds; N=80000; output `/dev/null`
- **before:** `setvbuf(_IONBF)` + `fprintf` each iter
- **after:** `setvbuf` 1 MiB `_IOFBF` + same `fprintf` each iter (+ `fflush`)
- **ref:** compute-only silent loop (ceiling)
- Raw lines: [`cp-printf-in-loop.jsonl`](cp-printf-in-loop.jsonl)
- Companion negatives: `case3_dead_printf.c` / lint probe `case3_if0.c` (static fire, no time delta)

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-21 Asia/Shanghai (JSONL `ts` is UTC) |
| Compiler | **cc (Debian 14.2.0-19) 14.2.0** · flags `cc -std=c11 -O2` |
| Median before (`unbuffered_fprintf`) | ~14.05 ms |
| Median after (`buffered_fprintf`) | ~2.94 ms |
| **ratio before/after (unbuf/buf)** | **~4.8×** |
| Silent ref | ~0.025 ms · unbuf/silent ≈ **561×** |

Companion STATIC-VS-O2 case2 ≈ **3.8×** unbuf/buf; case3 dead/`#if 0` ≈ **1.0×**.

## Lint mapping

`cperf-lint` cp-printf-in-loop fires on `printf`/`fprintf`/`puts` (and friends) inside a loop-body window, with dump/debug/`print*` / `#if DUMP|DEBUG|…` / path suppressions. Default severity is **off** (G3 demote) under [evidence-policy](../docs/evidence-policy.md): measured agreement exists for *hot* I/O, but correlation with “finding ⇒ cost” is **partial** (preprocessor-blind `#if 0`, dump noise). Enable per-tree with `--severity cp-printf-in-loop=hint` (or `error`) only when the path is known hot.

## Limits

- Scanner is not a preprocessor; `#if 0` can still produce findings.
- Buffered vs unbuffered is one fix; often the right fix is not printing on the hot path at all.
- `/dev/null` microbench understates real tty/file cost; still enough to show the smell matters when hot.
