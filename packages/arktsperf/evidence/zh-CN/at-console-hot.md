# at-console-hot — 循环中的控制台（Node 代理）

**状态:** 已测量 (节点代理)

## 主张

每次迭代的 `console.log`（标准输出被丢弃）比安静循环加一次日志在 Node/V8 上慢得多。

## 如何测量

- 测试工具：`examples/bench/evidence_at001_at003.js`
- **运行时：node-proxy**
- N_CONSOLE=20000

- 原始行：[`at-console-hot.jsonl`](../at-console-hot.jsonl)

## 运行时（本证据文件）

| Field | Value |
|-------|--------|
| 时间 | 2026-10-22 亚洲/上海 (JSONL `ts` 为 UTC) |
| 运行时 | **node-proxy** |
| node | **v20.19.2** |
| v8 | **11.3.244.8-node.38** |
| 中值之前 (`console_in_loop`) | ~24.79 毫秒 |
| (`quiet_then_once`) 之后的中位数 | ~0.1194 毫秒 |
| **前/后比率** | **~208×** |

## 与 lint 的对应

`arktsperf-lint` 在控制台热点：严重性保持包的默认值（见证据政策）。JSONL 是 **Node 代理**，不是设备。

## 限制

- I/O / 控制台环境依赖。
- 默认保持 **关闭**。
