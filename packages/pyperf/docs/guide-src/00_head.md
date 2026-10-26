# Python performance guide (v0)

Fewer quadratic builders, quieter hot paths.

> **Scope: CPython 3.10+.** Claims that assert speedups name a local example or are marked provisional. **Corpus lint counts are heuristic dogfood**, not benchmarks.

## How to read this

1. **Measure first** (`timeit`, `py-spy`, `cProfile`).
2. Treat each chapter as a checklist.
3. PyPy / other VMs differ — re-bench.

## Contents

- [0. Scope and method](#0-scope-and-method)
- [1. Strings and lists](#1-strings-and-lists)
- [2. Hot I/O](#2-hot-io)
- [Lint map](#lint-map)

