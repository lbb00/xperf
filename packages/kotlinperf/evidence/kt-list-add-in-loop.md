# kt-list-add-in-loop — ArrayList empty vs capacity

**Status:** measured

## Claim

At N=2e6 boxed Ints, empty `ArrayList()` + add vs `ArrayList(n)` measured ~**2.1×**.

## How measured

- Harness: `examples/bench/EvidenceKt.kt` → jar
- kotlinc 2.0.21 / JRE 21

- Raw lines: [`kt-list-add-in-loop.jsonl`](kt-list-add-in-loop.jsonl)

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-22 Asia/Shanghai (JSONL `ts` is UTC) |
| kotlin | **2.0.21** |
| jre | **21.0.12.1** |
| Median before (`list_add_empty`) | 5.303875 ms |
| Median after (`arraylist_capacity`) | 3.358458 ms |
| **ratio before/after** | **~1.58×** |

## Lint mapping

`kotlinperf-lint` kt-list-add-in-loop: keep default; kit-local KT* only.

## Limits

- Boxing dominates; capacity helps some. Not a jvmperf JMH ID.
- Default stays **off**.
