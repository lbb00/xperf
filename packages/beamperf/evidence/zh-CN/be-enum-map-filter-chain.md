# be-enum-map-filter-chain — Enum.map |> Enum.filter 链

**状态：** 已测量

## 主张

将 `Enum.map/2` 然后 `Enum.filter/2`（或 `Enum.reject/2`）链接起来会分配一个中间列表，并且比单个 `Enum.reduce` 在一次遍历中同时进行映射和过滤要慢（在 OTP 29 / Elixir 1.20.4 上对于 N≈2e5 的整数约慢 ~6.93× 和 ~6.18×）。

## 如何测量

- 测试工具：`packages/beamperf/examples/bench/evidence_be004_be005.exs`
- 时间测量：与 be-map-merge-hot 相同；N=200000 个整数，包含负数和正数
- 对 A：`map(*2) |> filter(>0)` 与 单次 reduce + 反转（匹配优秀的 `one_pass`）
- 对 B：`map(+1) |> reject(==0)` 与 单次 reduce + 反转
- 原始行数据：[`be-enum-map-filter-chain.jsonl`](../be-enum-map-filter-chain.jsonl)

## 运行时（本证据文件）

| Field | Value |
|-------|--------|
| 时间 | 2026-10-22 亚洲/上海 (JSONL `ts` 为 UTC) |
| Elixir | **1.18.3** |
| OTP | **27** |
| 中值之前 (`map_filter_chain`) | 4.546 毫秒 |
| (`one_pass_reduce`) 后的中位数 | 0.656 毫秒 |
| **前/后比例** | **~6.93×** |
| `map_reject_chain` 之前的中位数 | 5.498 毫秒 |
| `one_pass_reject` 后的中位数 | 0.890 毫秒 |
| **前/后比例** | **~6.18×** |

## 与 lint 的对应

`beamperf-lint` 会在 `Enum.map` 被管道送入 `Enum.filter` / `Enum.reject` 时触发 `be-enum-map-filter-chain`。严重性保持 **提示** (~4.5×；不升级)。

## 限制

- 纯整数变换的微基准测试；实际管道可能更倾向于清晰或使用 Stream。
- `Enum` 是急切的 — Stream 会改变情况。
- 一次遍历的 reduce 先构建反转的列表然后再反转；其他一次遍历的结构（推导式）可能略有不同。
