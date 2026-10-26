# C# performance guide (v0)

Fewer reallocating lists, quieter hot paths.

> **Scope: modern C# (.NET).** Claims that assert speedups name a local example or are marked provisional. **Corpus lint counts are heuristic dogfood**, not benchmarks.

## How to read this

1. **Measure first** (BenchmarkDotNet, `dotnet-trace`).
2. Treat each chapter as a checklist.
3. Runtime / GC settings differ — re-bench.

## Contents

- [How to read this](#how-to-read-this)
- [1. Lists and strings](#1-lists-and-strings)
- [2. Hot I/O](#2-hot-io)
- [Lint map](#lint-map)

