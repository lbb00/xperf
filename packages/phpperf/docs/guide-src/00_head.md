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

