# Kotlin performance guide (v0)

Kotlin-first collection, string, and I/O checklists. For measured JVM evidence (JMH/JOL), see sibling [jvmperf](../../jvmperf/).

> **Scope: Kotlin 1.9+ on JVM.** This kit does not replace [jvmperf](../../jvmperf/). Do not invent JMH ratios here — link or re-bench.
> Speedup claims cite a local bench, an upstream source, or are marked provisional. Corpus residual counts are lint hit counts, not wall-time savings.

Profile first (JMH via jvmperf, or simple wall timers). Coroutine `launch` in a tight loop is often a correctness or load smell — profile before rewriting.

## Contents

- [1. Collections](#1-collections)
- [2. Strings and hot I/O](#2-strings-and-hot-io)
- [Lint map](#lint-map)

