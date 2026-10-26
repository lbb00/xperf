# jp-enum-key-hash-collection

## Claim

`HashMap`/`HashSet` with enum keys is slower and allocates more than `EnumMap`/`EnumSet` for small enum key sets.

## How measured

- Source: `J32_RuleEvidenceBatch.jsonl`
- JDK **27 (27+35)**, JVM args `-XX:+UseCompactObjectHeaders`
- **before:** `hashMap_enumKey`
- **after:** `enumMap`

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-23 Asia/Shanghai |
| before | **660.673** ns_per_op, **192.010** B/op |
| after | **56.779** ns_per_op, **0.001** B/op |
| **ratio before/after** | **~11.6×** |

## Lint mapping / policy

Policy **error** (~11.6× time; HashMap also ~192 B/op vs ~0).

## Limits

Microbench on this machine; see `scripts/run-static-vs-hotspot.sh`. Do not invent ratios. Corpus residual ≠ speedup.
