# Lua performance guide (v0)

Fewer table resizes, fewer quadratic string joins, quieter hot loops.

> **Scope: Lua 5.1–5.4 / LuaJIT-shaped patterns.** Speedup claims cite a local bench, an upstream source, or are marked provisional. Corpus residual counts are lint hit counts, not wall-time savings.

Profile first (LuaJIT `-jv`, simple wall timers). Treat chapters as checklists, not rewrite mandates.

## Contents

- [1. Tables](#1-tables)
- [2. Strings and hot I/O](#2-strings-and-hot-io)
- [Lint map](#lint-map)

