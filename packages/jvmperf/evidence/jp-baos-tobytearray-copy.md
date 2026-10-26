# jp-baos-tobytearray-copy

## Claim

`ByteArrayOutputStream.toByteArray()` copies; prefer `writeTo(out)` on a reused BAOS.

## How measured

- Source: `J32_RuleEvidenceBatch.jsonl`
- JDK **27 (27+35)**, JVM args `-XX:+UseCompactObjectHeaders`
- **before:** `toByteArray_4k`
- **after:** `writeTo_reuse`

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-23 Asia/Shanghai |
| before | **13982.720** ns_per_op, **8224.210** B/op |
| after | **140.556** ns_per_op, **0.002** B/op |
| **ratio before/after** | **~99.5×** |

## Lint mapping / policy

Policy **error** (~99×).

## Limits

Microbench on this machine; see `scripts/run-static-vs-hotspot.sh`. Do not invent ratios. Corpus residual ≠ speedup.
