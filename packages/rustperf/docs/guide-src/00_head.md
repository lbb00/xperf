# Rust performance guide (v0)

Less allocator chatter, fewer surprise string / print stalls.

> **Scope: Rust edition 2021+.** Claims that assert speedups name a local example, an upstream source, or are marked provisional. **Corpus lint counts are heuristic dogfood**, not benchmarks.

## 0. Scope and method

1. **Measure first** (`cargo bench`, `criterion`, `perf`).
2. Treat each chapter as a checklist, not a rewrite mandate.
3. LLVM optimizations change costs — re-bench after toolchain bumps.

## Contents

- [0. Scope and method](#0-scope-and-method)
- [1. Allocation and clone](#1-allocation-and-clone)
- [2. Strings and hot I/O](#2-strings-and-hot-io)
- [Lint map](#lint-map)

