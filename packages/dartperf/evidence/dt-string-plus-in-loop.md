# dt-string-plus-in-loop — string + in loop

**Status:** measured

## Claim

`s = s + i.toString()` is much slower than `StringBuffer` (~208×) for N=30000 on Dart 3.13.7.

## How measured

- Harness: evidence_dt.dart

- Raw lines: [`dt-string-plus-in-loop.jsonl`](dt-string-plus-in-loop.jsonl)

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-22 Asia/Shanghai (JSONL `ts` is UTC) |
| dart | **3.13.6** |
| Median before (`string_plus`) | 95.331 ms |
| Median after (`string_buffer`) | 0.458 ms |
| **ratio before/after** | **~208×** |

## Lint mapping

`dartperf-lint` dt-string-plus-in-loop: keep default severity.

## Limits

- Default stays **off**.
