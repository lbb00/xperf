# kt-println-in-loop — println in loop

**Status:** measured

## Claim

Per-iteration `println` to `/dev/null` is much slower than quiet loop + one println (~270× on Kotlin 2.4.21 / JDK 27).

## How measured

- Harness: EvidenceKt.kt
- N=20000

- Raw lines: [`kt-println-in-loop.jsonl`](kt-println-in-loop.jsonl)

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-22 Asia/Shanghai (JSONL `ts` is UTC) |
| kotlin | **2.0.21** |
| jre | **21.0.12.1** |
| Median before (`println_in_loop`) | 8.620792 ms |
| Median after (`println_once`) | 0.031875 ms |
| **ratio before/after** | **~270×** |

## Lint mapping

`kotlinperf-lint` kt-println-in-loop: keep default; kit-local KT* only.

## Limits

- Default stays **off**.
