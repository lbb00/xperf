# be-io-puts-hot — 循环中的 IO.puts

**状态：** 已测量

## 主张

每次迭代的 `IO.puts`（空组长）比在 OTP 29 / Elixir 1.20.4 上先求和然后一次性 `IO.puts` 慢好几个数量级。之后的样本是 0.000834 毫秒，所以比例接近计时器的下限。

## 如何测量

- 测试工具：`examples/bench/evidence_be001_be003.exs`
- N=5000；IO 重定向到空进程

- 原始行: [`be-io-puts-hot.jsonl`](../be-io-puts-hot.jsonl)

## 运行时（本证据文件）

| Field | Value |
|-------|--------|
| 时间 | 2026-10-22 亚洲/上海 (JSONL `ts` 为 UTC) |
| otp | **27** |
| elixir | **1.18.3** |
| 循环内 `io_puts_in_loop` 之前的中位值 | 3.627 毫秒 |
| `io_once_after` 之后的中位数 | 0.000834 毫秒 |
| **前/后比例** | **~4349×** |

## 与 lint 的对应

`beamperf-lint` be-io-puts-hot：保持软件包默认严重性；证据不会自动升级。

## 限制

- 输入/输出 / 消息传递成本；依赖环境。
- 默认保持 **关闭**。
