## 1. Tables

`table.insert` without a known final size still works, but repeated growth in a hot loop can hurt. Prefer `t[#t+1] = x` with a pre-sized array part when `n` is known, or set fields by index.

```lua
local t = {}
for i = 1, n do
  t[i] = i
end
```

