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

## 1. Tables

`table.insert` without a known final size still works, but repeated growth in a hot loop can hurt. Prefer `t[#t+1] = x` with a pre-sized array part when `n` is known, or set fields by index.

```lua
local t = {}
for i = 1, n do
  t[i] = i
end
```

## 2. Strings and hot I/O

`a .. b` in a loop builds many temporaries. Prefer collecting parts then `table.concat`. Keep `print` out of tight loops (gate or buffer).

## Lint map

| ID | Smell | Default |
|----|-------|---------|
| lu-table-insert-in-loop | table.insert / grow in loop | off |
| lu-string-concat-in-loop | string `..` in loop | error |
| lu-print-in-loop | `print` in loop | hint |

Escalate only with `evidence/lu-*.jsonl` — see [evidence-policy.md](evidence-policy.md). lu-print-in-loop has measured evidence but stays **hint** (I/O sink–dependent).

## References

- [XPerf playbook](../../../docs/playbook.md)
