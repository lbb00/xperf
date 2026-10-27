# ph-echo-hot — echo/fwrite each iter vs implode once

## Claim

Measured on this machine: primary hot case **`echo_each_iter`** ratio before/after **~21.31×** (faster after). Default severity stays **`hint`**. Do **not** escalate to `error` from this fill alone.

## How measured

- Harness: `packages/phpperf/examples/bench/evidence_ph001_ph003.php`
- Protocol: warm=3; median of 9 rounds; GC/collect where applicable
- Raw lines: [`ph-echo-hot.jsonl`](ph-echo-hot.jsonl)

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-23 Asia/Shanghai (machine clock; JSONL ts is UTC) |
| Toolchain | **PHP 8.5.12** |
| Median after (`implode_once`) | 0.575792 ms (ops=20000, ratio=1.000000) |
| Median before (`echo_each_iter`) | 12.272208 ms (ops=20000, ratio=21.313613) |
| **Primary ratio before/after** | **~21.31×** (`echo_each_iter`) |

Direction and absolute ms are N/machine/opt-sensitive. Re-run the harness after toolchain or machine changes.

## Lint mapping

`phpperf-lint` **ph-echo-hot** default stays **`hint`**. Escalate recommended: **no**.

## Limits

- Microbench; not an app profile.
- Small-N rows may sit near timer noise; prefer hot (non-small) cases for ratio claims.
- I/O rules (print/echo/puts/writeln) discard to `/dev/null` — env-dependent.
