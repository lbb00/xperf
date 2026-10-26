# Lua performance guide (v0)

Fewer table resizes, fewer quadratic string joins, quieter hot loops.

> **Scope: Lua 5.1–5.4 / LuaJIT-shaped patterns.** Claims that assert speedups name a local example or are provisional. **Corpus lint counts are heuristic dogfood**, not benchmarks.

## How to read this

1. **Measure first** (LuaJIT `-jv`, simple wall timers).
2. Treat each chapter as a checklist, not a rewrite mandate.

## Contents

- [0. Scope and method](#0-scope-and-method)
- [1. Tables](#1-tables)
- [2. Strings and hot I/O](#2-strings-and-hot-io)
- [Lint map](#lint-map)

