# jp-hot-payload-copy

## Claim

Hot-path `new byte[header+payload]` + arraycopy each frame allocates; reuse a buffer when framing.

## How measured

- Source: `J32_RuleEvidenceBatch.jsonl`
- JDK **27 (27+35)**, JVM args `-XX:+UseCompactObjectHeaders`
- **before:** `newFrameEach_1k`
- **after:** `reuseBuffer_1k`

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-23 Asia/Shanghai |
| before | **2655.939** ns_per_op, **1040.037** B/op |
| after | **16.820** ns_per_op, **0.000** B/op |
| **ratio before/after** | **~158×** |

## Lint mapping / policy

Policy **error** (~158×).

## Limits

Microbench on this machine; see `scripts/run-static-vs-hotspot.sh`. Do not invent ratios. Corpus residual ≠ speedup.
