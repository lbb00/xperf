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

## 1. Collections

Prefer `ArrayList(n)` / `MutableList` with capacity when size is known. Avoid allocating a fresh list each iteration when a reused buffer works. Cross-link: jvmperf `jp-unpresized-collection` / `jp-collection-chain` for measured collection smells.

## 2. Strings and hot I/O

`s += x` in a loop is a classic builder case (`StringBuilder` / `buildString`). Keep `println` out of tight loops. For measured string concat, see jvmperf `jp-string-concat-in-loop`.

## Lint map

| ID | Smell | Default |
|----|-------|---------|
| kt-list-add-in-loop | list alloc / add growth in loop | off |
| kt-string-plus-in-loop | string `+=` in loop | off |
| kt-println-in-loop | `println` in loop | off |

Escalate only with `evidence/<rule>.jsonl` — see [evidence-policy.md](evidence-policy.md). Measured JVM claims: [jvmperf](../../jvmperf/).

## References

- [XPerf playbook](../../../docs/playbook.md)
- [jvmperf](../../jvmperf/)
