## 1. Table

不知道最终大小时 `table.insert` 仍可用，但热循环里反复扩容会受伤。已知 `n` 时，优先预分配数组部分后用 `t[#t+1] = x`，或按索引写字段。

```lua
local t = {}
local t = {}
for i = 1, n do
for i = 1, n do
  t[i] = i
  t[i] = i
end
end
```
