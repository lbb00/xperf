# jp-log-in-loop

## Claim

Building log strings (`"x=" + x`) before a level check still allocates when debug is off. Guard with `isDebugEnabled()` (or structured lazy args).

## How measured

- Source: `J32_RuleEvidenceBatch.jsonl`
- JDK **27 (27+35)**, JVM args `-XX:+UseCompactObjectHeaders`
- **before:** `concatAlways_debugOff_n1000`
- **after:** `guarded_debugOff_n1000`

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-23 Asia/Shanghai |
| before | **2838.115** ns_per_op, **23200.045** B/op |
| after | **6543.092** ns_per_op, **0.096** B/op |
| **ratio before/after** | **~0.43×** time (mean), alloc still ~**23200 B** vs ~0 |

## Lint mapping / policy

JDK 27 mean time went the other way (~0.43×) because one guarded sample spiked to ~25 µs; the other four sit around 0.4–3.5 µs, next to concat at ~2.6–3.7 µs. Allocation is still ~23200 B/op versus ~0.

A later direction check on an idle 16-core host (Temurin 21.0.13, load 0.96, warm 5, median of 9) is not a replacement of this JSONL. Building `"x=" + x` for 1000 ints, debug off, 200 repetitions per sample: concat median 1.129 ms, guarded median 0.062 ms, about 18×. The first four guarded samples were 0.28–0.45 ms and the rest sat at 0.048–0.062 ms, so the guard still wins if those early samples are kept. Default severity stays **off**.

## Limits

Microbench on this machine; see `scripts/run-static-vs-hotspot.sh`. Do not invent ratios. Corpus residual ≠ speedup.
