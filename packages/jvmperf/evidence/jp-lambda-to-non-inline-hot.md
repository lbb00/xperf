# jp-lambda-to-non-inline-hot

## Claim

Lambda passed to a **non-inline** higher-order function boxes/allocates; `inline` keeps it near zero alloc.

## How measured

- Source: `K14_LambdaCopyAlloc.jsonl`
- JDK **27 (27+35)**, Kotlin **2.4.21**, JVM args `-XX:+UseCompactObjectHeaders`. Linux x64, load 0.21.
- **before:** `repeatSumBoxed_n1e4`
- **after:** `repeatSumInline_n1e4`

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-23 |
| before | **15439.7** ns_per_op, **3897.9** B/op |
| after | **32990.8** ns_per_op, **16.0** B/op |
| **ratio before/after** | **~0.47×** time, **~244×** B/op |

## Lint mapping / policy

Allocation is still about 244× (was ~283×). Time went the other way on this run: the non-inline call was faster, about 0.47×. The rule stays for the allocation. Default severity is **off** in `Rule.java` (run it with `--enable`).

## Limits

Microbench on this machine; see `scripts/run-static-vs-hotspot.sh`. Do not invent ratios. Corpus residual ≠ speedup.
