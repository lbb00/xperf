# Dart performance guide (v0)

Fewer list resizes, fewer string `+` temporaries, quieter hot loops.

> **Scope: Dart 3.x (VM / Flutter).** Speedup claims cite a local bench, an upstream source, or are marked provisional. Corpus residual counts are lint hit counts, not wall-time savings.

Profile first (`benchmark_harness`, DevTools CPU profiler). Treat chapters as checklists, not rewrite mandates.

## Contents

- [1. Lists](#1-lists)
- [2. Strings and hot I/O](#2-strings-and-hot-io)
- [Lint map](#lint-map)

## 1. Lists

`List.add` in a hot loop is fine when capacity growth amortizes, but allocating a fresh growable list every iteration is not. Prefer `List.filled` / `List.generate` / known length when possible.

Lint: `dt-list-add-empty` (default off); `dt-growable-add-empty` (empty growable list + `add` in a size-hinted loop; default hint).

## 2. Strings and hot I/O

`s = s + x` in a loop builds many strings. Prefer `StringBuffer`. Keep `print` out of tight loops.

Lint: `dt-string-plus-hot`, `dt-print-hot` (default off).

## Lint map

| ID | Smell | Default |
|----|-------|---------|
| dt-list-add-empty | List grow / `add` without capacity cue | off |
| dt-string-plus-hot | string `+` in loop | off |
| dt-print-hot | `print` in loop | off |
| dt-growable-add-empty | empty growable list + `add` in size-hinted loop | hint |

Escalate only with `evidence/<rule>.jsonl` — see [evidence-policy.md](evidence-policy.md).

## References

- [XPerf playbook](../../../docs/playbook.md)
