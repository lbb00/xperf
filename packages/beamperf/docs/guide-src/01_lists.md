## 1. Lists

`list ++ [x]` (Elixir) or `List ++ [X]` (Erlang) in a loop is quadratic. Prefer `[x | acc]` then `Enum.reverse/1` / `lists:reverse/1`, or use proper accumulators.

`Map.merge/2` or `Keyword.merge/2` on every element of a reduce was measured slower than `Map.put/3` (see [evidence-policy.md](evidence-policy.md)). Use `Map.put/3`, or merge outside only when the other map stays the same. Chained `Enum.map/2` then `Enum.filter/2` builds an intermediate list. On the measured chain of about 200000 integers that was about 4.5×; a short list is a different cost.

Companion lint: **be-list-concat-reduce**, **be-map-merge-in-loop**, **be-enum-map-filter-chain** (all default **hint**).

