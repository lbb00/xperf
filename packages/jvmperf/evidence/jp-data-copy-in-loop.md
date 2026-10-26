# jp-data-copy-in-loop

## Claim

Hot `data class.copy(...)` in a loop allocates a new instance each iteration; locals avoid that.

## How measured

- Source: `K14_LambdaCopyAlloc.jsonl`
- JDK **27 (27+35)**, Kotlin **2.4.21**, JVM args `-XX:+UseCompactObjectHeaders`. Linux x64, load 0.21. The JDK 25 time pair was about 1149×.
- **before:** `simulateCopy_n1e4`
- **after:** `simulateLocals_n1e4`

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-23 |
| before | **20884.1** ns_per_op, **240024.0** B/op |
| after | **100.6** ns_per_op, **24.0** B/op |
| **ratio before/after** | **~207.6×** time, **~10001×** B/op |

## Lint mapping / policy

Policy **error**. Time is about 208× (was ~1149×). Allocation is still about 10001× B/op.

## Limits

Microbench on this machine; see `scripts/run-static-vs-hotspot.sh`. Do not invent ratios. Corpus residual ≠ speedup.
