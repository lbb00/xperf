# C++ performance guide (v0)

Fewer reallocating containers, quieter hot paths.

> **Scope: C++17.** Claims that assert speedups name a local example or are marked provisional. **Corpus lint counts are heuristic dogfood**, not benchmarks.
>
> **cppperf vs cperf:** this kit is dedicated C++. Sibling **cperf** covers C11/C17 (+ light C++). Prefer this package for `std::vector` / `std::string` / iostream smells.

## How to read this

1. **Measure first** (`perf`, Tracy, `std::chrono`).
2. Treat each chapter as a checklist.
3. libstdc++ and libc++ differ — re-bench.

## Contents

- [How to read this](#how-to-read-this)
- [1. Containers and strings](#1-containers-and-strings)
- [2. Hot I/O](#2-hot-io)
- [Lint map](#lint-map)

