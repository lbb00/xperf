# Kotlin performance guide (v0)

Kotlin-first collection, string, and I/O checklists. For measured JVM evidence (JMH/JOL), see sibling [jvmperf](../../jvmperf/).

> **Scope: Kotlin 1.9+ on JVM.** This kit does not replace [jvmperf](../../jvmperf/). Do not invent JMH ratios here — link or re-bench.
> Speedup claims cite a local bench, an upstream source, or are marked provisional. Corpus residual counts are lint hit counts, not wall-time savings.

Profile first (JMH via jvmperf, or simple wall timers). Coroutine `launch` in a tight loop is often a correctness or load smell — profile before rewriting.

## Contents

- [1. Collections](#1-collections)
- [2. Strings and hot I/O](#2-strings-and-hot-io)
- [Lint map](#lint-map)

## 1. Collections

Prefer `ArrayList(n)` / `MutableList` with capacity when size is known. Avoid allocating a fresh list each iteration when a reused buffer works. Cross-link: jvmperf `jp-unpresized-collection` / `jp-collection-chain` for measured collection smells.

Lint: `kt-list-add-hot` (default off).

## 2. Strings and hot I/O

`s += x` in a loop is a classic builder case (`StringBuilder` / `buildString`). Keep `println` out of tight loops. For measured string concat, see jvmperf `jp-string-concat-hot`.

Lint: `kt-string-plus-hot`, `kt-println-hot` (default off).

## Lint map

| ID | Smell | Default |
|----|-------|---------|
| kt-list-add-hot | list alloc / add growth in loop | off |
| kt-string-plus-hot | string `+=` in loop | off |
| kt-println-hot | `println` in loop | off |

Escalate only with `evidence/<rule>.jsonl` — see [evidence-policy.md](evidence-policy.md). Measured JVM claims: [jvmperf](../../jvmperf/).

## References

- [XPerf playbook](../../../docs/playbook.md)
- [jvmperf](../../jvmperf/)
