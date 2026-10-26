# gp-defer-in-loop — defer in loop vs close each (synthetic closer)

## Claim

Measured on this machine: primary hot case **`defer_in_loop`** ratio before/after **~46.02×** (faster after). Default severity stays **`hint`**. Do **not** escalate to `error` from this fill alone — ratio is strong but policy/default and G3 OK-idiom history keep severity unchanged.

## How measured

- Harness: `packages/goperf/examples/bench/evidence_gp.go`
- Protocol: warm=3; median of 9 rounds; GC/collect where applicable
- Raw lines: [`gp-defer-in-loop.jsonl`](gp-defer-in-loop.jsonl)

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-23 Asia/Shanghai (machine clock; JSONL ts is UTC) |
| Toolchain | **go1.27.3** |
| Median after (`close_each`) | 0.038000 ms (ops=20000, ratio=1.000000) |
| Median before (`defer_in_loop`) | 1.748917 ms (ops=20000, ratio=46.024132) |
| Median after (`small_close_each`) | 0.000084 ms (ops=100, ratio=1.000000) |
| Median before (`small_defer_in_loop`) | 0.002209 ms (ops=100, ratio=26.297619) |
| **Primary ratio before/after** | **~46.02×** (`defer_in_loop`) |

Direction and absolute ms are N/machine/opt-sensitive. Re-run the harness after toolchain or machine changes.

## Lint mapping

`goperf-lint` **gp-defer-in-loop** default stays **`hint`**. Escalate recommended: **no**.

## Limits

- Microbench; not an app profile.
- Small-N rows may sit near timer noise; prefer hot (non-small) cases for ratio claims.
- I/O rules (print/echo/puts/writeln) discard to `/dev/null` — env-dependent.
