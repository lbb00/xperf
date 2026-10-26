# pp-print-in-loop — print in loop vs join once (stdout discarded)

## Claim

Measured on this machine: primary hot case **`print_in_loop`** ratio before/after **~2.10×** (faster after). Default severity stays **`off`**. Do **not** escalate to `error` from this fill alone.

## How measured

- Harness: `packages/pyperf/examples/bench/evidence_pp.py`
- Protocol: warm=3; median of 9 rounds; GC/collect where applicable
- Raw lines: [`pp-print-in-loop.jsonl`](pp-print-in-loop.jsonl)

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-23 Asia/Shanghai (machine clock; JSONL ts is UTC) |
| Toolchain | **CPython 3.15.1** |
| Median after (`print_join_once`) | 1.073375 ms (ops=20000, ratio=1.000000) |
| Median before (`print_in_loop`) | 2.258042 ms (ops=20000, ratio=2.103684) |
| **Primary ratio before/after** | **~2.10×** (`print_in_loop`) |

Direction and absolute ms are N/machine/opt-sensitive. Re-run the harness after toolchain or machine changes.

## Lint mapping

`pyperf-lint` **pp-print-in-loop** default stays **`off`**. Escalate recommended: **no**.

## Limits

- Microbench; not an app profile.
- Small-N rows may sit near timer noise; prefer hot (non-small) cases for ratio claims.
- I/O rules (print/echo/puts/writeln) discard to `/dev/null` — env-dependent.
