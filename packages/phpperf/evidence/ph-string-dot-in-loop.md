# ph-string-dot-in-loop — string .= vs implode

## Claim

Measured on this machine: primary hot case **`str_dot`** ratio before/after **~2.54×** (faster after). Default severity stays **`off`**. Do **not** escalate to `error` from this fill alone.

## How measured

- Harness: `packages/phpperf/examples/bench/evidence_ph001_ph003.php`
- Protocol: warm=3; median of 9 rounds; GC/collect where applicable
- Raw lines: [`ph-string-dot-in-loop.jsonl`](ph-string-dot-in-loop.jsonl)

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-23 Asia/Shanghai (machine clock; JSONL ts is UTC) |
| Toolchain | **PHP 8.5.12** |
| Median after (`implode`) | 0.319334 ms (ops=50000, ratio=1.000000) |
| Median before (`str_dot`) | 0.811167 ms (ops=50000, ratio=2.540184) |
| Median after (`small_implode`) | 0.000375 ms (ops=100, ratio=1.000000) |
| Median before (`small_str_dot`) | 0.000917 ms (ops=100, ratio=2.445333) |
| **Primary ratio before/after** | **~2.54×** (`str_dot`) |

Direction and absolute ms are N/machine/opt-sensitive. Re-run the harness after toolchain or machine changes.

## Lint mapping

`phpperf-lint` **ph-string-dot-in-loop** default stays **`off`**. Escalate recommended: **no**.

## Limits

- Microbench; not an app profile.
- Small-N rows may sit near timer noise; prefer hot (non-small) cases for ratio claims.
- I/O rules (print/echo/puts/writeln) discard to `/dev/null` — env-dependent.
