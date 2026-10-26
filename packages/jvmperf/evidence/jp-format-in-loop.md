# jp-format-in-loop — `String.format` / format in hot loop

## Claim

Hot `String.format` (and similar) is much slower and more allocating than building the same string with `StringBuilder` appends (or a reused `DateTimeFormatter` for date-shaped text) on HotSpot.

## How measured

- Harness: `jmh-benches/.../J27_FormatHot.java` via `scripts/run_jmh.sh J27_FormatHot`
- Work: reps=1 format of a small pattern; JMH 1.37 avgt + `-prof gc`; `-XX:+UseCompactObjectHeaders`
- **before:** `stringFormat`
- **after:** `stringBuilderAppend` (also recorded: `dateTimeFormatter`)
- Raw: `research/bench-results/J27_FormatHot.jsonl`
- Correlate: STATIC-VS-HOTSPOT case 3

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-23 Asia/Shanghai |
| JDK | **27 (27+35)** |
| JVM args | `-XX:+UseCompactObjectHeaders` |
| before `stringFormat[reps=1]` | **1022.449 ns/op**, **1368.006 B/op** |
| after `stringBuilderAppend[reps=1]` | **35.147 ns/op**, **88.000 B/op** |
| **ratio before/after** | **~29.1×** time |
| vs `dateTimeFormatter[reps=1]` | **141.005 ns/op** → format/DTF ~**7.3×** |

## Lint mapping

`jvmperf-lint` jp-format-in-loop (`format-in-loop`). Default severity **off** (run it with `--enable`).

## Limits

- Logging / rare error paths: wall-clock often irrelevant — keep suppressions.
- One-shot scripts and exception messages are weak escalate targets.
