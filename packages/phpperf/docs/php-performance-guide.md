# PHP performance guide (v0)

Fewer quadratic builders, quieter hot paths.

> **Scope: PHP 8+.** Speedup claims cite a local bench, an upstream source, or are marked provisional. Corpus residual counts are lint hit counts, not wall-time savings.

Profile first (`hrtime`, Blackfire, Xdebug). Extensions and JIT differ — re-bench.

## Contents

- [1. Strings and arrays](#1-strings-and-arrays)
- [2. Hot I/O](#2-hot-io)
- [Lint map](#lint-map)

## 1. Strings and arrays

`$s .= $piece` in a loop can still be costly at scale; prefer collectors + `implode`. Repeated `$a = array_merge($a, …)` copies; prefer `$a[] = $item`.

Lint: `ph-string-dot-hot` (default off); `ph-array-merge-rebind` (default error).

## 2. Hot I/O

`echo` / `print` in a tight loop flushes. Gate debug output or buffer.

Lint: `ph-echo-hot` (default hint).

## Lint map

| ID | Smell | Default |
|----|-------|---------|
| ph-string-dot-hot | string `.=` in loop | off |
| ph-array-merge-rebind | `array_merge` rebinding in loop | error |
| ph-echo-hot | `echo` / `print` in loop | hint |

Escalate only with `evidence/ph-*.jsonl` — see [evidence-policy.md](evidence-policy.md).

## References

- [XPerf playbook](../../../docs/playbook.md)
