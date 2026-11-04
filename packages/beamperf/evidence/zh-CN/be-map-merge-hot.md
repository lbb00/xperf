# be-map-merge-hot — Map.merge / Keyword.merge 在循环中

**状态：** 已测量

## 主张

`Enum.reduce` 对每个元素调用 `Map.merge/2` 比使用 `Map.put/3` 更新要慢（在 OTP 29 / Elixir 1.20.4 上，多键折叠大约慢 2.30 倍，单键大约慢 1.77 倍）。在 reduce 中使用 `Keyword.merge/2` 比 `Keyword.put/3` 大约慢 **2.00 倍**。

## 如何测量

- 测试环境：`packages/beamperf/examples/bench/evidence_be004_be005.exs`
- 测量时间：`:erlang.monotonic_time(:nanosecond)`；预热=3；取9次的中位数；每次采样前进行垃圾回收
- 对照 A：N=5000 个映射 `%{i => i, :tag => …}` 使用 `Map.merge` 与 N=5000 个 `%{k:, v:}` 使用 `Map.put`（匹配良好的 `put_in_loop`）
- 对照 B：N=5000 个单键映射 —— 在相同形状下使用 `Map.merge` 与 `Map.put`
- 对照 C：N=2000 个关键字列表 —— `Keyword.merge` 与 `Keyword.put`
- 原始数据文件行：[`be-map-merge-hot.jsonl`](../be-map-merge-hot.jsonl)

## 运行时（本证据文件）

| Field | Value |
|-------|--------|
| 时间 | 2026-10-22 亚洲/上海 (JSONL `ts` 为 UTC) |
| Elixir | **1.18.3** |
| OTP | **27** |
| 中位数之前（`map_merge_reduce`） | 2.099 毫秒 |
| (`map_put_kv`) 之后的中位数 | 0.912 毫秒 |
| **前后比例** | **~2.30×** |
| `map_merge_single` 之前的中位数 | 1.726 毫秒 |
| (`map_put_single`) 后的中位数 | 0.973 毫秒 |
| **前/后比例** | **~1.77×** |
| 中值之前 (`keyword_merge_reduce`) | 2.304 毫秒 |
| (`keyword_put`) 之后的中位数 | 1.153 毫秒 |
| **前/后比例** | **~2.00×** |

## 与 lint 的对应

`beamperf-lint` 在 reduce/loop 内部的 `Map.merge` / `Keyword.merge` 上触发 be-map-merge-hot。严重性保持 **提示** — 最强的一对约 7 倍是真实的，但此次未升级。

## 限制

- A 组比较多键合并映射与 key-value 结构的放置（夹具对齐；工作内容不完全相同）。
- 单键合并与放置的差异仅约 1.3 倍——当映射保持很小时，增长成本很小。
- 关键字列表是线性的；合并成本随关键字长度增加而增加。
- 未测量 `:maps.merge/2` NIF 或大型持久结构。
