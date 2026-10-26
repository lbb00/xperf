# jp-boxed-stream

## Claim

Boxed `Stream` reduce (`Integer::sum` / similar) is far slower and more allocating than `mapToInt`/`mapToLong` on HotSpot.

## How measured

- Source: `J32_RuleEvidenceBatch.jsonl`
- JDK **27 (27+35)**, JVM args `-XX:+UseCompactObjectHeaders`
- **before:** `boxedReduce_n10k`
- **after:** `mapToInt_n10k`

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-23 Asia/Shanghai |
| before | **745977.453** ns_per_op, **160178.813** B/op |
| after | **20050.141** ns_per_op, **207.420** B/op |
| **ratio before/after** | **~37.2×** |

## Lint mapping / policy

Policy **error** (wall-clock ~37×).

## Limits

Microbench on this machine; see `scripts/run-static-vs-hotspot.sh`. Do not invent ratios. Corpus residual ≠ speedup.
