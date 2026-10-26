# jp-string-intern-in-loop

## Claim

`String.intern()` in a hot loop contends on the string table and is much slower than plain inserts (dedupe with a local map/Interner if needed).

## How measured

- Source: `J32_RuleEvidenceBatch.jsonl`
- JDK **27 (27+35)**, JVM args `-XX:+UseCompactObjectHeaders`
- **before:** `intern_n2000`
- **after:** `plain_n2000`

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-23 Asia/Shanghai |
| before | **166619.350** ns_per_op, **48002.651** B/op |
| after | **26335.679** ns_per_op, **48000.417** B/op |
| **ratio before/after** | **~6.33×** |

## Lint mapping / policy

Policy **error** (~6.3×).

## Limits

Microbench on this machine; see `scripts/run-static-vs-hotspot.sh`. Do not invent ratios. Corpus residual ≠ speedup.
