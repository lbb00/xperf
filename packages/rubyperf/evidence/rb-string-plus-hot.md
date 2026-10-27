# rb-string-plus-hot — string += vs <<

## Claim

Measured on this machine: primary hot case **`str_plus`** ratio before/after **~53.79×** (faster after). Default severity stays **`off`**. Do **not** escalate to `error` from this fill alone — ratio is strong but policy/default and G3 OK-idiom history keep severity unchanged.

## How measured

- Harness: `packages/rubyperf/examples/bench/evidence_rb.rb`
- Protocol: warm=3; median of 9 rounds; GC/collect where applicable
- Raw lines: [`rb-string-plus-hot.jsonl`](rb-string-plus-hot.jsonl)

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-22 Asia/Shanghai (machine clock; JSONL ts is UTC) |
| Toolchain | **Ruby 4.0.8** |
| Median after (`shovel`) | 1.164000 ms (ops=50000, ratio=1.000000) |
| Median before (`str_plus`) | 62.611000 ms (ops=50000, ratio=53.789518) |
| Median after (`small_shovel`) | 0.003000 ms (ops=100, ratio=1.000000) |
| Median before (`small_str_plus`) | 0.005000 ms (ops=100, ratio=1.666718) |
| **Primary ratio before/after** | **~53.79×** (`str_plus`) |

Direction and absolute ms are N/machine/opt-sensitive. Re-run the harness after toolchain or machine changes.

## Lint mapping

`rubyperf-lint` **rb-string-plus-hot** default stays **`off`**. Escalate recommended: **no**.

## Limits

- Microbench; not an app profile.
- Small-N rows may sit near timer noise; prefer hot (non-small) cases for ratio claims.
- I/O rules (print/echo/puts/writeln) discard to `/dev/null` — env-dependent.
