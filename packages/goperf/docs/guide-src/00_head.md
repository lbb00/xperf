# Go performance guide (v0)

Less allocation chatter, fewer surprise `fmt` / string-growth stalls.

> **Scope: Go 1.21+.** Claims that assert speedups name a local example, an upstream source, or are marked provisional. **Corpus lint counts are heuristic dogfood**, not benchmarks.

## How to read this

1. **Measure first** (`go test -bench`, `pprof`, `benchstat`).
2. Treat each chapter as a checklist, not a rewrite mandate.
3. Escape analysis and inlining change costs — re-bench after toolchain bumps.

## Contents

- [How to read this](#how-to-read-this)
- [1. Allocation](#1-allocation)
- [2. Strings and formatting](#2-strings-and-formatting)
- [Lint map](#lint-map)

