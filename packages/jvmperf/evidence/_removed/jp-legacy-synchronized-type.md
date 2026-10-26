# jp-legacy-synchronized-type

## Claim

Legacy synchronized `StringBuffer`/`Hashtable` — single-thread micro shows only a tiny StringBuffer tax; Hashtable put can even beat ConcurrentHashMap without contention. Rule stays a review for contested / API-legacy cases.

## How measured

- Source: `J32_RuleEvidenceBatch.jsonl`
- JDK **25.0.4.1+1-1-deb13u1-Debian**, JVM args `-XX:+UseCompactObjectHeaders`
- **before:** `stringBuffer_parts256`
- **after:** `stringBuilder_parts256`

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-21 Asia/Shanghai |
| before | **1746.396** ns_per_op, **3344.028** B/op |
| after | **1621.458** ns_per_op, **1992.026** B/op |
| **ratio before/after** | **~1.08×** |

## Lint mapping / policy

Policy **hint** (time ~1.08×; Hashtable vs CHM single-thread **negative** for CHM).

## Limits

Microbench on this machine; see `scripts/run-static-vs-hotspot.sh`. Do not invent ratios. Corpus residual ≠ speedup.
