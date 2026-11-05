# Lua performance guide (v0)

Fewer table resizes, fewer quadratic string joins, quieter hot loops.

> **Scope: Lua 5.1–5.4 / LuaJIT-shaped patterns.** Speedup claims cite a local bench, an upstream source, or are marked provisional. Corpus residual counts are lint hit counts, not wall-time savings.

Profile first (LuaJIT `-jv`, simple wall timers). Treat chapters as checklists, not rewrite mandates.

## Contents

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

Lint: `lu-table-insert-hot` (default off).

## 2. Strings and hot I/O

`a .. b` in a loop builds many temporaries. Prefer collecting parts then `table.concat`. Keep `print` out of tight loops (gate or buffer).

Lint: `lu-string-concat-hot` (default error); `lu-print-hot` (default hint).

## Lint map

| ID | Smell | Default |
|----|-------|---------|
| lu-table-insert-hot | table.insert / grow in loop | off |
| lu-string-concat-hot | string `..` in loop | error |
| lu-print-hot | `print` in loop | hint |

Escalate only with `evidence/lu-*.jsonl` — see [evidence-policy.md](evidence-policy.md). `lu-print-hot` has measured evidence but stays hint (I/O sink–dependent).

## References

- [XPerf playbook](../../../docs/playbook.md)
