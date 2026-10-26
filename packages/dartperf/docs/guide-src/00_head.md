# Dart performance guide (v0)

Fewer list resizes, fewer string `+` temporaries, quieter hot loops.

> **Scope: Dart 3.x (VM / Flutter).** Claims that assert speedups name a local example or are provisional. **Corpus lint counts are heuristic dogfood**, not benchmarks.

## How to read this

1. **Measure first** (`benchmark_harness`, DevTools CPU profiler).
2. Treat each chapter as a checklist, not a rewrite mandate.

## Contents

- [How to read this](#how-to-read-this)
- [1. Lists](#1-lists)
- [2. Strings and hot I/O](#2-strings-and-hot-io)
- [Lint map](#lint-map)

