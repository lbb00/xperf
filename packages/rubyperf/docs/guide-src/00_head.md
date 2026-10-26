# Ruby performance guide (v0)

Fewer quadratic builders, quieter hot paths.

> **Scope: MRI Ruby 3+.** Claims that assert speedups name a local example or are marked provisional. **Corpus lint counts are heuristic dogfood**, not benchmarks.

## 0. Scope and method

1. **Measure first** (`benchmark`, stackprof).
2. Treat each chapter as a checklist.
3. JRuby / TruffleRuby differ — re-bench.

## Contents

- [0. Scope and method](#0-scope-and-method)
- [1. Strings, arrays, and hashes](#1-strings-arrays-and-hashes)
- [2. Hot I/O](#2-hot-io)
- [Lint map](#lint-map)

