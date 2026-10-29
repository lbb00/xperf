# kt-string-plus-hot — string += vs buildString

**Status:** measured

## Claim

`s +=` in a loop is vastly slower than `buildString` (~521×) for N=30000 on Kotlin 2.4.21 / JDK 27.

## How measured

- Harness: EvidenceKt.kt

- Raw lines: [`kt-string-plus-hot.jsonl`](kt-string-plus-hot.jsonl)

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-22 Asia/Shanghai (JSONL `ts` is UTC) |
| kotlin | **2.0.21** |
| jre | **21.0.12.1** |
| Median before (`string_plus`) | 93.440375 ms |
| Median after (`buildString`) | 0.179375 ms |
| **ratio before/after** | **~521×** |

## Lint mapping

`kotlinperf-lint` kt-string-plus-hot: keep default; kit-local KT* only.

## Limits

- Default stays **off**.
