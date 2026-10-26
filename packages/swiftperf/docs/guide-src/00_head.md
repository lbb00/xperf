# Swift performance guide (v0)

Fewer force-unwraps on hot paths, fewer quadratic string builders.

> **Scope: Swift 5.9+.** Claims that assert speedups name a local example or are marked provisional. **Corpus lint counts are heuristic dogfood**, not benchmarks.

## 0. Scope and method

1. **Measure first** (Instruments, `swift package benchmark` when available).
2. Treat each chapter as a checklist.
3. ARC and specialization change costs — re-bench after toolchain bumps.

## Contents

- [0. Scope and method](#0-scope-and-method)
- [1. Optionals and hot paths](#1-optionals-and-hot-paths)
- [2. Strings, collections, and printing](#2-strings-collections-and-printing)
- [3. Formatters, JSON, and regular expressions](#3-formatters-json-and-regular-expressions)
- [Lint map](#lint-map)

