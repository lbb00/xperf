# rb-puts-hot — puts each vs join once

## Claim

Measured on this machine: primary hot case **`puts_each`** ratio before/after **~3.58×** (faster after). Default severity stays **`off`**. Do **not** escalate to `error` from this fill alone.

## How measured

- Harness: `packages/rubyperf/examples/bench/evidence_rb.rb`
- Protocol: warm=3; median of 9 rounds; GC/collect where applicable
- Raw lines: [`rb-puts-hot.jsonl`](rb-puts-hot.jsonl)

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-22 Asia/Shanghai (machine clock; JSONL ts is UTC) |
| Toolchain | **Ruby 4.0.8** |
| Median after (`join_once`) | 1.149000 ms (ops=20000, ratio=1.000000) |
| Median before (`puts_each`) | 4.110000 ms (ops=20000, ratio=3.577023) |
| **Primary ratio before/after** | **~3.58×** (`puts_each`) |

Direction and absolute ms are N/machine/opt-sensitive. Re-run the harness after toolchain or machine changes.

## Lint mapping

`rubyperf-lint` **rb-puts-hot** default stays **`off`**. Escalate recommended: **no**.

## Limits

- Microbench; not an app profile.
- Small-N rows may sit near timer noise; prefer hot (non-small) cases for ratio claims.
- I/O rules (print/echo/puts/writeln) discard to `/dev/null` — env-dependent.
