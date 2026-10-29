# rs-println-hot — writeln/println each iter vs buffer then write

## Claim

Writing a line on every loop iteration to `/dev/null` is **~64.9×** slower than buffering with `writeln!` into a `String` then one `write_all` (rustc 1.99.1 `-C opt-level=3`, this machine). Versus a quiet compute loop the gap is enormous (I/O-bound) — that pair is listed for context only and must **not** drive escalate. Default stays **`hint`** (env/I/O dependent).

## How measured

- Harness: `packages/rustperf/examples/bench/evidence_rs003_rs005_rs006.rs`
- Build: `rustc -C opt-level=3`
- Timer: `std::time::Instant`; warm=3; median of 9; `black_box`
- Pair A: N=20000
  - **before:** `writeln!(null, "{i}")` each iter
  - **after:** buffer lines then one write to `/dev/null`
- Pair B (context): same before vs quiet arithmetic (no I/O)
- Raw lines: [`rs-println-hot.jsonl`](rs-println-hot.jsonl)

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-22 Asia/Shanghai (machine clock; JSONL `ts` is UTC) |
| rustc | **1.99.1** |
| Opt | **opt-level=3** |
| Median before (`writeln_each_iter`) | 6.582 ms |
| Median after (`buffer_then_write`) | 0.524 ms |
| **ratio buffer pair** | **~64.85×** |
| Median after (`quiet_compute`) | ~0.00005 ms |
| ratio writeln vs quiet | huge (I/O vs no-I/O — not escalate basis) |

## Lint mapping

`rustperf-lint` **rs-println-hot** default stays **`hint`**. Escalate recommended: **no** (I/O env-dependent, same class as lu-print-hot and cp-printf-hot).

## Limits

- Microbench; stdout discarded to `/dev/null`.
- Real TTY/stderr contention can change absolute ms dramatically.
- Does not measure `println!` macro formatting separately from write syscalls.
