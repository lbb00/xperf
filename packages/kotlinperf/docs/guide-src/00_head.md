# Kotlin performance guide (v0)

Kotlin-first collection / string / I/O checklists. For measured JVM evidence (JMH/JOL), see sibling **jvmperf**.

> **Scope: Kotlin 1.9+ on JVM.** This kit does **not** replace [jvmperf](../../jvmperf/). Do not invent JMH ratios here — link or re-bench.

## How to read this

1. **Measure first** (JMH via jvmperf, or simple wall timers).
2. Treat each chapter as a checklist, not a rewrite mandate.
3. Coroutine `launch` in a tight loop is often a correctness/load smell — profile before rewriting.

## Contents

- [How to read this](#how-to-read-this)
- [1. Collections](#1-collections)
- [2. Strings and hot I/O](#2-strings-and-hot-io)
- [Lint map](#lint-map)

