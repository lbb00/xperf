# rs-collect-vec-hot — collect::<Vec<_>> in loop vs .count()

## Claim

Measured on this machine: primary hot case **`collect_in_loop`** ratio before/after **~2.14×** (faster after). Default severity stays **`hint`**. Do **not** escalate to `error` from this fill alone.

## How measured

- Harness: `packages/rustperf/examples/bench/evidence_rs003_rs005_rs006.rs`
- Protocol: warm=3; median of 9 rounds
- Opt: `opt-level=3`
- Raw lines: [`rs-collect-vec-hot.jsonl`](rs-collect-vec-hot.jsonl)

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-22 Asia/Shanghai (machine clock; JSONL ts is UTC) |
| Toolchain | **1.85.1** |
| Opt | **opt-level=3** |
| Median after (`count_no_collect`) | 0.333875 ms (ops=5000, ratio=1.000000) |
| Median before (`collect_in_loop`) | 0.714542 ms (ops=5000, ratio=2.140148) |
| Median after (`small_count`) | 7.044250 ms (ops=50, ratio=1.000000) |
| Median before (`small_collect`) | 13.768250 ms (ops=50, ratio=1.954537) |
| **Primary ratio before/after** | **~2.14×** (`collect_in_loop`) |

Direction and absolute ms are N/machine/opt-sensitive. Re-run the harness after toolchain or machine changes.

## Lint mapping

`rustperf-lint` **rs-collect-vec-hot** default stays **`hint`**. Escalate recommended: **no**.

## Limits

- Microbench; not an app profile.
- Small-N rows may sit near timer noise; prefer hot (non-small) cases for ratio claims.
- I/O rules (print/echo/puts/writeln) discard to `/dev/null` — env-dependent.
