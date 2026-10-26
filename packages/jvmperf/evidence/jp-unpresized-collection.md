# jp-unpresized-collection — unpresized collection fill

## Claim

Filling an `ArrayList` (or similar) without an initial capacity allocates more and is often somewhat slower than `new ArrayList(n)` when `n` is known. On this machine the **time** cliff is **mild**; **B/op** agrees more clearly.

## How measured

- Harness: `J25_Presize.java` / `scripts/run_jmh.sh J25_Presize`
- **before:** `growFromDefault[n=10000]`
- **after:** `presized[n=10000]`
- Raw: `J25_Presize.jsonl`
- Correlate: STATIC-VS-HOTSPOT case 2 **PARTIAL**

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-23 Asia/Shanghai |
| JDK | **27 (27+35)** |
| JVM args | `-XX:+UseCompactObjectHeaders` |
| before n=10k | **117725.103 ns/op**, **326832.742 B/op** |
| after n=10k | **82357.177 ns/op**, **197992.522 B/op** |
| **ratio** | **~1.43×** time, **~1.65×** B/op |
| n=100k (same JSONL) | ~**1.37×** time, ~**1.44×** B/op |

## Lint mapping

Default severity **off** (run it with `--enable`; PARTIAL wall-clock). Evidence files exist so the claim is auditable; do not treat every jp-unpresized-collection corpus hit as a must-fix speed bug.

## Limits

- Unknown final size → cannot always presize; FP common on builders.
- Corpus residual still elevated after lint reverse-opt rounds — triage before escalating to `error`.
