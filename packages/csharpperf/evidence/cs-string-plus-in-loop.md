# cs-string-plus-in-loop — string += in loop

**Status:** measured

## Claim

Immutable `string +=` in a loop is vastly slower than `StringBuilder` for N=30000.

## How measured

- Harness: EvidenceCsBench
- N=30000

- Raw lines: [`cs-string-plus-in-loop.jsonl`](cs-string-plus-in-loop.jsonl)

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-22 Asia/Shanghai (JSONL `ts` is UTC) |
| dotnet | **8.0.32** |
| Median before (`string_plus_equals`) | 226.0176 ms |
| Median after (`stringbuilder`) | 0.0885 ms |
| **ratio before/after** | **~2554×** |

## Lint mapping

`csharpperf-lint` cs-string-plus-in-loop: keep default severity.

## Limits

- Default stays **off**. Large ratio is I/O-free CPU/alloc.
