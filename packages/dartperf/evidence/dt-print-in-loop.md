# dt-print-in-loop — print/write in loop

**Status:** measured

## Claim

Per-iteration sync write to `/dev/null` is much slower than one write after the loop (~2040× on Dart 3.13.7). The after sample is 0.004 ms, so the ratio sits close to the timer floor.

## How measured

- Harness: evidence_dt.dart
- N=10000

- Raw lines: [`dt-print-in-loop.jsonl`](dt-print-in-loop.jsonl)

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-22 Asia/Shanghai (JSONL `ts` is UTC) |
| dart | **3.13.6** |
| Median before (`print_in_loop`) | 8.159 ms |
| Median after (`print_once`) | 0.004 ms |
| **ratio before/after** | **~2040×** |

## Lint mapping

`dartperf-lint` dt-print-in-loop: keep default severity.

## Limits

- I/O proxy for `print`; default stays **off**.
