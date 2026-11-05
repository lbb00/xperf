## 1. List

循环里的 `list ++ [x]`（Elixir）或 `List ++ [X]`（Erlang）是平方级的。优先 `[x | acc]` 再 `Enum.reverse/1` / `lists:reverse/1`，或使用正确的累加器。

在 reduce 的每个元素上调用 `Map.merge/2` 或 `Keyword.merge/2`，测得比 `Map.put/3` 更慢（见 [evidence-policy.md](evidence-policy.md)）。用 `Map.put/3`；仅当另一 map 不变时，才在循环外 merge。链式 `Enum.map/2` 再 `Enum.filter/2` 会建中间 list。约 200000 整数的测量链大约 4.5×；短 list 成本不同。

Lint: `be-list-concat-reduce`, `be-map-merge-hot`, `be-enum-map-filter-chain`（all 默认 hint）
