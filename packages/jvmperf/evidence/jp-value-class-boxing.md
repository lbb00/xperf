# jp-value-class-boxing

## Claim

`@JvmInline` value classes box when used as generic/`Array`/`nullable` elements. On JDK 27 / Kotlin 2.4.21 the List path is about 4.0× the `IntArray` path in time and about 5.0× in allocation. The JDK 25 time pair was about 1.05×.

## How measured

- Source: `K15_ValueClassBoxing.jsonl`
- JDK **27 (27+35)**, Kotlin **2.4.21**, JVM args `-XX:+UseCompactObjectHeaders`. Linux x64, load 0.78.
- **before:** `sumBoxedList_UserId_n1e4`
- **after:** `sumPrimitive_intArray_n1e4`

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-23 |
| before | **65983.793** ns_per_op, **200056.0** B/op |
| after | **16566.447** ns_per_op, **40032.453** B/op |
| **ratio before/after** | **~3.98×** time, **~5.0×** B/op |

## Lint mapping / policy

Default severity **hint**. List vs `IntArray` is about 4.0× time and 5.0× B/op. The `Array<UserId>` path was 33385 ns/op and 200032 B/op, about 2.0× the `IntArray` time.

## Limits

Microbench on this machine; see `scripts/run-static-vs-hotspot.sh`. Do not invent ratios. Corpus residual ≠ speedup.
