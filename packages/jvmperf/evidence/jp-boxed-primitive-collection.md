# jp-boxed-primitive-collection — boxed primitive collection

## Claim

Hot sums (or similar scans) over `List<Integer>` / boxed collections are slower than the same work on `int[]` (or an unboxed stream) on HotSpot, mainly via **boxing, pointer chasing, and GC pressure** — not because static analysis detected a C2 failure.

## How measured

- Harness: `jmh-benches/.../J20_BoxingSum.java` via `scripts/run_jmh.sh J20_BoxingSum`
- Work: N=1_000_000 elements; JMH 1.37 avgt + `-prof gc`; `@Fork` appends `-XX:+UseCompactObjectHeaders`
- **before:** `sumArrayList` over `ArrayList<Integer>`
- **after:** `sumIntArray` over `int[]` (also recorded: `sumIntStream`)
- Raw research lines: `research/bench-results/J20_BoxingSum.jsonl`
- Correlate: `scripts/run-static-vs-hotspot.sh` case `1_boxing_sum`

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-23 Asia/Shanghai |
| JDK | **27 (27+35)** |
| JVM args | `-XX:+UseCompactObjectHeaders` (JMH `@Fork` jvmArgsAppend) |
| before `sumArrayList[n=1000000]` | **478817.125 ns/op** |
| after `sumIntArray[n=1000000]` | **363120.071 ns/op** |
| **ratio before/after** | **~1.32×** at n=1e6 |
| n=100000 (same JSONL) | list **205276.327** vs `int[]` **27867.230** → **~7.37×** |
| vs `sumIntStream[n=1000000]` | stream **618599.233 ns/op**, slower than the list |

A later direction check on an idle host (Temurin 21.0.13, load 0.16, warm 5, median of 9) is not a replacement of this JSONL. Values still start at 1000. n=1e5, 40 passes: list 2.014 ms, `int[]` 0.238 ms, about 8.5×. n=1e6, 8 passes: list 6.504 ms, `int[]` 0.589 ms, about 11×. Samples were tight. The JDK 27 n=1e6 ~1.32× does not reproduce here. Default stays **off**.

## Lint mapping

`jvmperf-lint` jp-boxed-primitive-collection (`boxed-primitive-collection`) flags `List<Integer>`, `Map<Long,…>`, Kotlin `List<Int>`, etc. Default severity **off** (run it with `--enable`); see [evidence-policy](../docs/evidence-policy.md).

## Limits

- Microbench, not an app profile; API boundaries that must expose boxed types are often false “wins.”
- Do **not** equate jp-boxed-primitive-collection with HotSpot deoptimization or “failed JIT.”
- Corpus dogfood still has FP on tests/fixtures — triage separately.
