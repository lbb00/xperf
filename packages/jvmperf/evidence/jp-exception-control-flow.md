# jp-exception-control-flow

## Claim

Using exceptions for expected parse failures is much slower than a digit check (and allocates exception objects).

## How measured

- Source: `J32_RuleEvidenceBatch.jsonl`
- JDK **27 (27+35)**, JVM args `-XX:+UseCompactObjectHeaders`
- **before:** `tryParse_n2000`
- **after:** `digitCheck_n2000`

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-23 Asia/Shanghai |
| before | **230074.011** ns_per_op, **342403.663** B/op |
| after | **58066.417** ns_per_op, **0.862** B/op |
| **ratio before/after** | **~3.96×** |

## Lint mapping / policy

Measured ~3.96× on the JDK 27 mean. Two digit-check samples spiked, so this mean is softer than the steady ~4 µs samples.

A later direction check on an idle host (Temurin 21.0.13, load 0.16) is not a replacement of this JSONL. Same 2000 strings, every fifth is `nope`, 80 repetitions, warm 5, median of 9: try/parse 14.509 ms, digit check 0.535 ms, about 27×. Both sides were tight. The JDK 27 ~4× mean was the spike. Default severity stays **off**.

## Limits

Microbench on this machine; see `scripts/run-static-vs-hotspot.sh`. Do not invent ratios. Corpus residual ≠ speedup.
