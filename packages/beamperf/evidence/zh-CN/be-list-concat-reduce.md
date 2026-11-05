# be-list-concat-reduce — 在 reduce 中使用 list ++

**状态：** 已测量

## 主张

`acc ++ [i]` 在 reduce 中比 cons + `Enum.reverse/1` 慢得多（约 776 倍），在 OTP 29 / Elixir 1.20.4 上测试。

## 如何测量

- 测试工具：`examples/bench/evidence_be001_be003.exs`
- N=8000；预热=3；9次的中位数；`:erlang.monotonic_time(:nanosecond)`

- 原始行: [`be-list-concat-reduce.jsonl`](../be-list-concat-reduce.jsonl)

## 运行时（本证据文件）

| Field | Value |
|-------|--------|
| 时间 | 2026-10-22 亚洲/上海 (JSONL `ts` 为 UTC) |
| otp | **27** |
| elixir | **1.18.3** |
| 中位数之前 (`list_plusplus`) | 95.715 毫秒 |
| (`cons_reverse`) 之后的中位数 | 0.123 毫秒 |
| **前/后比率** | **~776×** |

## 与 lint 的对应

`beamperf-lint` be-list-concat-reduce：保持软件包默认严重性；证据不会自动升级。

## 限制

- 二次列表增长；实际代码应优先使用 cons 或 `:lists.reverse`。
- 尽管比例很大，默认仍保留 **提示**（此轮不会升级严重性）。
