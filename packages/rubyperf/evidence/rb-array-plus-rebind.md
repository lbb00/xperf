# rb-array-plus-rebind — a = a + [x] vs <<

## Claim

Measured on this machine: primary hot case **`array_plus_rebind`** ratio before/after **~131.34×** (faster after). Default severity stays **`off`**. Do **not** escalate to `error` from this fill alone — ratio is strong but policy/default and G3 OK-idiom history keep severity unchanged.

## How measured

- Harness: `packages/rubyperf/examples/bench/evidence_rb.rb`
- Protocol: warm=3; median of 9 rounds; GC/collect where applicable
- Raw lines: [`rb-array-plus-rebind.jsonl`](rb-array-plus-rebind.jsonl)

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-22 Asia/Shanghai (machine clock; JSONL ts is UTC) |
| Toolchain | **Ruby 4.0.8** |
| Median after (`shovel`) | 0.441000 ms (ops=20000, ratio=1.000000) |
| Median before (`array_plus_rebind`) | 57.921000 ms (ops=20000, ratio=131.340176) |
| Median after (`small_shovel`) | 0.003000 ms (ops=100, ratio=1.000000) |
| Median before (`small_array_plus`) | 0.005000 ms (ops=100, ratio=1.666615) |
| **Primary ratio before/after** | **~131.34×** (`array_plus_rebind`) |

Direction and absolute ms are N/machine/opt-sensitive. Re-run the harness after toolchain or machine changes.

## Lint mapping

`rubyperf-lint` **rb-array-plus-rebind** default stays **`off`**. Escalate recommended: **no**.

## Limits

- Microbench; not an app profile.
- Small-N rows may sit near timer noise; prefer hot (non-small) cases for ratio claims.
- I/O rules (print/echo/puts/writeln) discard to `/dev/null` — env-dependent.
