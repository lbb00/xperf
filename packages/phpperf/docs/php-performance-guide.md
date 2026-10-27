# PHP performance guide (v0)

Fewer quadratic builders, quieter hot paths.

> **Scope: PHP 8+.** Claims that assert speedups name a local example or are marked provisional. **Corpus lint counts are heuristic dogfood**, not benchmarks.

## How to read this

1. **Measure first** (`hrtime`, Blackfire, Xdebug).
2. Treat each chapter as a checklist.
3. Extensions / JIT differ — re-bench.

## Contents

- [0. Scope and method](#0-scope-and-method)
- [1. Strings and arrays](#1-strings-and-arrays)
- [2. Hot I/O](#2-hot-io)
- [Lint map](#lint-map)

## 1. Strings and arrays

`$s .= $piece` in a loop can still be costly at scale; prefer collectors + `implode`. Repeated `$a = array_merge($a, …)` copies; prefer `$a[] = $item`.

Companion lint: **ph-string-dot-hot**, **ph-array-merge-rebind**.

## 2. Hot I/O

`echo` / `print` in a tight loop flushes. Gate debug output or buffer.

Companion lint: **ph-echo-hot**.

## Lint map

| ID | Smell | Default |
|----|-------|---------|
| ph-string-dot-hot | string `.=` in loop | off |
| ph-array-merge-rebind | `array_merge` rebinding in loop | **error** |
| ph-echo-hot | `echo` / `print` in loop | hint |

Escalate only with `evidence/ph-*.jsonl` — see [evidence-policy.md](evidence-policy.md).

## References

- [XPerf playbook](../../../docs/playbook.md)
