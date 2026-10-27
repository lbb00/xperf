# jp-string-concat-hot — string concat in loop (`+=` / `s = s + …`)

## Claim

Hot `String` concatenation with `+=` (or `s = s + x`) inside a loop is much slower and more allocating than a `StringBuilder` (especially presized) on HotSpot. Cost is repeated immutable `String` allocation / copy — not a C2 “failure.”

## How measured

- Harness: `jmh-benches/.../J23_StringConcat.java` via `scripts/run_jmh.sh J23_StringConcat`
- Work: concatenate `parts` fixed fragments; JMH 1.37 avgt + `-prof gc`; `@Fork` appends `-XX:+UseCompactObjectHeaders`
- **before:** `plusEquals`
- **after:** `stringBuilderPresized` (also recorded: `stringBuilderDefault`)
- Raw research lines: `research/bench-results/J23_StringConcat.jsonl`
- Correlate sibling: extend STATIC-VS-HOTSPOT reading with this pair (alloc/time YES)

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-23 Asia/Shanghai |
| JDK | **27 (27+35)** |
| JVM args | `-XX:+UseCompactObjectHeaders` |
| before `plusEquals[parts=256]` | **69754.657 ns/op**, **141296.445 B/op** |
| after `stringBuilderPresized[parts=256]` | **3278.274 ns/op**, **2104.021 B/op** |
| **ratio before/after** | **~21.3×** time, **~67×** B/op |
| parts=64 (same JSONL) | plusEquals **1043.665** → SB presized **628.989** → **~1.66×** time |

## Lint mapping

`jvmperf-lint` jp-string-concat-hot (`string-concat-in-loop`). Policy severity **error** under [evidence-policy](../docs/evidence-policy.md).

## Limits

- One-shot / rare paths: wall-clock often irrelevant.
- Java 9+ `invokedynamic` concat helps **expression** trees; **loop-carried** `+=` still rebuilds.
- Do not equate with HotSpot deoptimization.
