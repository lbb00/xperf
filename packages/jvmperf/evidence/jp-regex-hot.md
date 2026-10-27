# jp-regex-hot — regex compile in loop

## Claim

Compiling a `Pattern` on every call still allocates about **2.4×** more than a reused `static final Pattern`. On JDK 27 the 1024-line time pair went the other way (**~0.76×**, compile-each faster). Lines=64 time is about **1.07×**.

## How measured

- Harness: `J26_RegexCompile.java` / `scripts/run_jmh.sh J26_RegexCompile`
- Work: match `lines` strings with a fixed regex; JMH 1.37 avgt + `-prof gc`; `-XX:+UseCompactObjectHeaders`
- **before:** `compileEachCall`
- **after:** `staticFinalPattern`
- Raw: `research/bench-results/J26_RegexCompile.jsonl`

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-23 Asia/Shanghai |
| JDK | **27 (27+35)** |
| JVM args | `-XX:+UseCompactObjectHeaders` |
| before `compileEachCall[lines=1024]` | **128040.677 ns/op**, **827392.817 B/op** |
| after `staticFinalPattern[lines=1024]` | **167595.045 ns/op**, **344065.068 B/op** |
| **ratio before/after** | **~0.76×** time (compile-each faster), **~2.40×** B/op |
| lines=64 (same JSONL) | **~1.07×** time, **~2.40×** B/op |

## Lint mapping

Default severity **off** (run it with `--enable`); wall-clock is only barely past ~1.3× and not a clear escalate cliff like jp-string-concat-hot. Evidence files exist so the claim is auditable; keep as an opt-in review prompt until a hotter workload shows a larger time cliff.

A later direction check on an idle 16-core host (Temurin 21.0.13, load 0.96) is not a replacement of this JSONL. 200 repetitions of the 1024-line split, warm 5, median of 9: compile-each 33.023 ms, static pattern 19.738 ms, about 1.67×, samples tight. On that JDK the static pattern is slightly faster. The JDK 27 time pair stays the recorded one, and the ~2.4× allocation gap is why the rule stays.

## Limits

- Dynamic patterns (user-supplied regex) cannot be static-final — suppressions expected.
- Matching cost dominates when the pattern is already compiled; compile-once wins shrink.
- Do not invent a larger ratio than J26 records.
