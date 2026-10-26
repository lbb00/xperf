# jp-collection-chain

## Claim

Kotlin eager `map`/`filter` chains allocate full intermediate lists; `asSequence()` (or imperative) avoids that when only a prefix is consumed.

## How measured

- Source: `K13_SequenceAlloc.jsonl`
- JDK **27 (27+35)**, Kotlin **2.4.21**, JVM args `-XX:+UseCompactObjectHeaders`. Linux x64, load 0.12 at start. The JDK 25 pair was about 391×.
- **before:** `eagerChain_n1e5_take5`
- **after:** `sequenceChain_n1e5_take5`

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-23 |
| before | **839101.9** ns_per_op, **2568512.0** B/op |
| after | **3170.2** ns_per_op, **232.0** B/op |
| **ratio before/after** | **~264.7×** |
| imperative | **1178.0** ns_per_op, **80.0** B/op, about **712×** vs eager |

## Lint mapping / policy

Measured ~265× vs sequence; ~712× vs imperative. Allocation is unchanged at about 2.6 MB versus 232 B. Default severity is **off** in `Rule.java` (run it with `--enable`).

## Limits

Microbench on this machine; see `scripts/run-static-vs-hotspot.sh`. Do not invent ratios. Corpus residual ≠ speedup.
